import vitis
import time

client = vitis.create_client()
client.set_workspace(path="/home/mpsocv2/vitis_cdhs")

try:
    client.delete_component(name="test_fsbl")
except: pass
try:
    client.delete_component(name="test_platform")
except: pass

advanced_options = client.create_advanced_options_dict(dt_overlay="0")
platform = client.create_platform_component(
    name="test_platform",
    hw_design="/home/mpsocv2/vivado_cdhs/cdhs_vivado/design_1_wrapper.xsa",
    os="standalone",
    cpu="psu_cortexa53_0",
    domain_name="standalone_psu_cortexa53_0",
    no_boot_bsp=True,
    generate_dtb=False,
    advanced_options=advanced_options,
    architecture="64-bit",
    compiler="gcc"
)

platform = client.get_component(name="test_platform")
platform.build()

domain = platform.add_domain(
    cpu="psu_cortexa53_0",
    os="standalone",
    name="fsbl_domain",
    display_name="fsbl_domain",
    support_app="zynqmp_fsbl",
    generate_dtb=False
)

# Re-build to export new domain into XPFM
platform.build()

comp = client.create_app_component(
    name="test_fsbl",
    platform="/home/mpsocv2/vitis_cdhs/test_platform/export/test_platform/test_platform.xpfm",
    domain="fsbl_domain",
    template="zynqmp_fsbl"
)
comp.build()

print("ALL SUCCESS!")
vitis.dispose()
