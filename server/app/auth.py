"""Autenticación: contraseña para la persona, token para el agente."""

import hmac

from argon2 import PasswordHasher
from argon2.exceptions import VerificationError, VerifyMismatchError
from fastapi import HTTPException, Request
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer

from .config import get_settings

COOKIE = "audiorev_session"
MAX_AGE = 30 * 24 * 3600

_hasher = PasswordHasher()


def hash_password(raw: str) -> str:
    return _hasher.hash(raw)


def verify_password(raw: str, stored: str) -> bool:
    if not stored:
        return False
    try:
        return _hasher.verify(stored, raw)
    except (VerifyMismatchError, VerificationError):
        return False


def _serializer() -> URLSafeTimedSerializer:
    return URLSafeTimedSerializer(get_settings().session_secret, salt="audiorev")


def issue_session(user: str = "jorge") -> str:
    return _serializer().dumps({"u": user})


def read_session(token: str) -> str | None:
    try:
        return _serializer().loads(token, max_age=MAX_AGE).get("u")
    except (BadSignature, SignatureExpired):
        return None


def require_user(request: Request) -> str:
    settings = get_settings()
    if not settings.trust_proxy_user and not settings.password_hash:
        # Sin contraseña configurada y sin proxy de confianza: el usuario
        # decidió no poner ninguna barrera porque el enlace es privado y
        # solo él lo conoce. Se entra directamente, sin pantalla de login.
        return "jorge"
    if settings.trust_proxy_user:
        # Esto solo es seguro porque el proxy inverso fija y sobrescribe esta
        # cabecera antes de reenviar la petición; si la app quedara expuesta
        # directamente en este modo, cualquier cliente podría fijarla y
        # suplantar al usuario.
        user = request.headers.get(settings.trust_proxy_user)
        if not user:
            raise HTTPException(status_code=401, detail="No autenticado")
        return user

    token = request.cookies.get(COOKIE)
    user = read_session(token) if token else None
    if not user:
        raise HTTPException(status_code=401, detail="No autenticado")
    return user


def require_api_token(request: Request) -> None:
    expected = get_settings().api_token
    header = request.headers.get("Authorization", "")
    given = header[7:] if header.startswith("Bearer ") else ""
    if not expected or not hmac.compare_digest(given, expected):
        raise HTTPException(status_code=401, detail="Token no válido")
