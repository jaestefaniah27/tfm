----------------------------------------------------------------------------------
-- axi4_slave_mem  — modelo de memoria AXI4 (full) esclava para S8b
--
-- Sirve las lecturas/escrituras de un maestro AXI4 (aqui el axi_mcdma: fetch y
-- writeback de BDs por M_AXI_SG, y escritura de datos por M_AXI_S2MM). Soporta
-- rafagas INCR, WSTRB, 32-bit. Single-outstanding por canal (suficiente para
-- observar correccion; el MCDMA no necesita concurrencia para funcionar).
--
-- La memoria es un array de bytes accesible por procedimientos del testbench
-- (mem_write32/mem_read32) para precargar los BDs y para inspeccionar lo escrito.
-- Se expone por puertos de depuracion: dbg_wr_beats (nº de escrituras de datos).
--
-- Nota: pensado para xsim, ADDR de 32 bits pero solo se decodifica MEM_BYTES.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axi4_slave_mem is
  generic (
    MEM_BYTES  : integer := 1048576;   -- 1 MiB
    ADDR_BASE  : integer := 0;         -- direccion base (los BDs y buffers van >= base)
    ID_WIDTH   : integer := 1
  );
  port (
    aclk    : in  std_logic;
    aresetn : in  std_logic;
    -- AW
    awaddr  : in  std_logic_vector(31 downto 0);
    awlen   : in  std_logic_vector(7 downto 0);
    awsize  : in  std_logic_vector(2 downto 0);
    awburst : in  std_logic_vector(1 downto 0);
    awvalid : in  std_logic;
    awready : out std_logic;
    -- W
    wdata   : in  std_logic_vector(31 downto 0);
    wstrb   : in  std_logic_vector(3 downto 0);
    wlast   : in  std_logic;
    wvalid  : in  std_logic;
    wready  : out std_logic;
    -- B
    bresp   : out std_logic_vector(1 downto 0);
    bvalid  : out std_logic;
    bready  : in  std_logic;
    -- AR
    araddr  : in  std_logic_vector(31 downto 0);
    arlen   : in  std_logic_vector(7 downto 0);
    arsize  : in  std_logic_vector(2 downto 0);
    arburst : in  std_logic_vector(1 downto 0);
    arvalid : in  std_logic;
    arready : out std_logic;
    -- R
    rdata   : out std_logic_vector(31 downto 0);
    rresp   : out std_logic_vector(1 downto 0);
    rlast   : out std_logic;
    rvalid  : out std_logic;
    rready  : in  std_logic;
    -- Debug
    dbg_data_bytes : out integer   -- bytes de datos escritos (para el sumidero S2MM)
  );
end axi4_slave_mem;

architecture sim of axi4_slave_mem is
  type mem_t is array (0 to MEM_BYTES-1) of std_logic_vector(7 downto 0);
  shared variable mem : mem_t := (others => (others => '0'));

  signal data_bytes : integer := 0;
begin

  dbg_data_bytes <= data_bytes;

  -- ── Canal de escritura: AW -> W(burst) -> B ─────────────────────────────
  wr_proc : process(aclk)
    variable addr    : integer;
    variable beats   : integer;
    variable i       : integer;
    variable idx     : integer;
    variable is_data : boolean;
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        awready <= '0'; wready <= '0'; bvalid <= '0'; bresp <= "00";
      else
        -- por defecto
        awready <= '0';
        -- aceptar B pendiente
        if bvalid = '1' and bready = '1' then
          bvalid <= '0';
        end if;

        -- aceptar direccion de escritura cuando no hay B pendiente
        if awvalid = '1' and awready = '0' and bvalid = '0' then
          addr  := to_integer(unsigned(awaddr)) - ADDR_BASE;
          beats := to_integer(unsigned(awlen)) + 1;
          awready <= '1';
          -- consumir los beats de W
          i := 0;
          -- marcar si esta escritura cae en zona de datos (>= 0x2000, buffers)
          is_data := (to_integer(unsigned(awaddr)) - ADDR_BASE) >= 16#2000#;
          wready <= '1';
          while i < beats loop
            wait until rising_edge(aclk) and wvalid = '1';
            idx := addr + i*4;
            for b in 0 to 3 loop
              if wstrb(b) = '1' and (idx+b) >= 0 and (idx+b) < MEM_BYTES then
                mem(idx+b) := wdata(b*8+7 downto b*8);
                if is_data then
                  data_bytes <= data_bytes + 1;
                end if;
              end if;
            end loop;
            i := i + 1;
          end loop;
          wready <= '0';
          awready <= '0';
          -- responder B
          bresp  <= "00";
          bvalid <= '1';
        end if;
      end if;
    end if;
  end process;

  -- ── Canal de lectura: AR -> R(burst) ────────────────────────────────────
  rd_proc : process(aclk)
    variable addr  : integer;
    variable beats : integer;
    variable i     : integer;
    variable idx   : integer;
    variable word  : std_logic_vector(31 downto 0);
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        arready <= '0'; rvalid <= '0'; rlast <= '0'; rresp <= "00";
        rdata <= (others => '0');
      else
        arready <= '0';
        if arvalid = '1' and arready = '0' and rvalid = '0' then
          addr  := to_integer(unsigned(araddr)) - ADDR_BASE;
          beats := to_integer(unsigned(arlen)) + 1;
          arready <= '1';
          wait until rising_edge(aclk);
          arready <= '0';
          i := 0;
          while i < beats loop
            idx := addr + i*4;
            for b in 0 to 3 loop
              if (idx+b) >= 0 and (idx+b) < MEM_BYTES then
                word(b*8+7 downto b*8) := mem(idx+b);
              else
                word(b*8+7 downto b*8) := (others => '0');
              end if;
            end loop;
            rdata  <= word;
            rresp  <= "00";
            if i = beats-1 then rlast <= '1'; else rlast <= '0'; end if;
            rvalid <= '1';
            wait until rising_edge(aclk) and rready = '1';
            i := i + 1;
          end loop;
          rvalid <= '0';
          rlast  <= '0';
        end if;
      end if;
    end if;
  end process;

end sim;
