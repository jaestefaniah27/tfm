from pathlib import Path

import pytest


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


@pytest.fixture(scope="session")
def tex_root(repo_root: Path) -> Path:
    return repo_root / "plantilla_tft_etsit"
