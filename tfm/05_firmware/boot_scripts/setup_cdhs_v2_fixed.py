import vitis

print("=" * 55)
print("  Vitis: platform_cdhs_v2_fixed + fsbl_cdhs_v2_fixed")
print("=" * 55)

client = vitis.create_client()
client.set_workspace(path="/home/mpsocv2/vitis_cdhs")

print()
print("[1/5] Creando plataforma 'platform_cdhs_v2_fixed'...")
advanced_options = client.create_advanced_options_dict(dt_overlay="0")
platform = client.create_platform_component(
    name="platform_cdhs_v2_fixed",
    hw_design="/home/mpsocv2/vivado_cdhs/cdhs_vivado/cdhs_vivado_wrapper.xsa",
    os="standalone",
    cpu="psu_cortexa53_0",
    domain_name="standalone_psu_cortexa53_0",
    no_boot_bsp=True,
    generate_dtb=False,
    advanced_options=advanced_options,
    architecture="64-bit",
    compiler="gcc"
)
print("[OK] Plataforma creada")

print()
print("[2/5] Compilando plataforma...")
platform = client.get_component(name="platform_cdhs_v2_fixed")
status = platform.build()
print("[OK] Plataforma compilada")

print()
print("[3/5] Añadiendo dominio FSBL...")
domain = platform.add_domain(
    cpu="psu_cortexa53_0",
    os="standalone",
    name="fsbl_domain",
    display_name="fsbl_domain",
    support_app="zynqmp_fsbl",
    generate_dtb=False
)
print("[OK] Dominio FSBL añadido")

print()
print("[3.5/5] Recompilando plataforma para actualizar el .xpfm...")
status = platform.build()
print("[OK] Plataforma actualizada")

print()
print("[4/5] Creando aplicación FSBL 'fsbl_cdhs_v2_fixed'...")
comp = client.create_app_component(
    name="fsbl_cdhs_v2_fixed",
    platform="/home/mpsocv2/vitis_cdhs/platform_cdhs_v2_fixed/export/platform_cdhs_v2_fixed/platform_cdhs_v2_fixed.xpfm",
    domain="fsbl_domain",
    template="zynqmp_fsbl"
)
print("[OK] App FSBL creada")

print()
print("[5/5] Compilando todo...")
status = platform.build()
print("[OK] Plataforma recompilada")
comp = client.get_component(name="fsbl_cdhs_v2_fixed")
comp.build()
print("[OK] FSBL compilado")

print()
print("=" * 55)
print("  VITIS SETUP COMPLETADO")
print("=" * 55)

vitis.dispose()
