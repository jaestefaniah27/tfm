import pexpect
import sys

child = pexpect.spawn('/home/mpsocv2/quick-start/app/serial_bridge/generate_boot.sh --no-sd --out out/03_MCDMA', encoding='utf-8')
child.logfile = sys.stdout

child.expect(r'Selecciona \[1-3\]:')
child.sendline('2') # Desde Vivado (solo exportar XSA)

child.expect(r'Selecciona el proyecto')
# We need to find which number is 03_MCDMA
# pexpect can read line by line
while True:
    idx = child.expect([r'([0-9]+)\).*03_MCDMA.*', r'Selecciona \['])
    if idx == 0:
        proj_num = child.match.group(1)
    elif idx == 1:
        break
child.sendline(proj_num)

child.expect(r'Nombre para esta configuración')
child.sendline('MCDMA')

# Next it might ask for bitstream if there are multiple. 
# Usually it auto-selects if there is only 1.
# Let's wait for EOF or another prompt.
idx = child.expect([r'Selecciona \[', pexpect.EOF], timeout=300)
if idx == 0:
    child.sendline('1')
    child.expect(pexpect.EOF, timeout=300)

