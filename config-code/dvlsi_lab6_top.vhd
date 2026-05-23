library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dvlsi_lab6_top is
  port (
        DDR_cas_n         : inout STD_LOGIC;
        DDR_cke           : inout STD_LOGIC;
        DDR_ck_n          : inout STD_LOGIC;
        DDR_ck_p          : inout STD_LOGIC;
        DDR_cs_n          : inout STD_LOGIC;
        DDR_reset_n       : inout STD_LOGIC;
        DDR_odt           : inout STD_LOGIC;
        DDR_ras_n         : inout STD_LOGIC;
        DDR_we_n          : inout STD_LOGIC;
        DDR_ba            : inout STD_LOGIC_VECTOR( 2 downto 0);
        DDR_addr          : inout STD_LOGIC_VECTOR(14 downto 0);
        DDR_dm            : inout STD_LOGIC_VECTOR( 3 downto 0);
        DDR_dq            : inout STD_LOGIC_VECTOR(31 downto 0);
        DDR_dqs_n         : inout STD_LOGIC_VECTOR( 3 downto 0);
        DDR_dqs_p         : inout STD_LOGIC_VECTOR( 3 downto 0);
        FIXED_IO_mio      : inout STD_LOGIC_VECTOR(53 downto 0);
        FIXED_IO_ddr_vrn  : inout STD_LOGIC;
        FIXED_IO_ddr_vrp  : inout STD_LOGIC;
        FIXED_IO_ps_srstb : inout STD_LOGIC;
        FIXED_IO_ps_clk   : inout STD_LOGIC;
        FIXED_IO_ps_porb  : inout STD_LOGIC
       );
end entity; -- dvlsi_lab6_top

architecture arch of dvlsi_lab6_top is

  constant N : integer := 32;  -- image width (in pixels)

  component design_1_wrapper is
    port (
          DDR_cas_n         : inout STD_LOGIC;
          DDR_cke           : inout STD_LOGIC;
          DDR_ck_n          : inout STD_LOGIC;
          DDR_ck_p          : inout STD_LOGIC;
          DDR_cs_n          : inout STD_LOGIC;
          DDR_reset_n       : inout STD_LOGIC;
          DDR_odt           : inout STD_LOGIC;
          DDR_ras_n         : inout STD_LOGIC;
          DDR_we_n          : inout STD_LOGIC;
          DDR_ba            : inout STD_LOGIC_VECTOR( 2 downto 0);
          DDR_addr          : inout STD_LOGIC_VECTOR(14 downto 0);
          DDR_dm            : inout STD_LOGIC_VECTOR( 3 downto 0);
          DDR_dq            : inout STD_LOGIC_VECTOR(31 downto 0);
          DDR_dqs_n         : inout STD_LOGIC_VECTOR( 3 downto 0);
          DDR_dqs_p         : inout STD_LOGIC_VECTOR( 3 downto 0);
          FIXED_IO_mio      : inout STD_LOGIC_VECTOR(53 downto 0);
          FIXED_IO_ddr_vrn  : inout STD_LOGIC;
          FIXED_IO_ddr_vrp  : inout STD_LOGIC;
          FIXED_IO_ps_srstb : inout STD_LOGIC;
          FIXED_IO_ps_clk   : inout STD_LOGIC;
          FIXED_IO_ps_porb  : inout STD_LOGIC;
          --------------------------------------------------------------------------
          ----------------------------------------------- PL (FPGA) COMMON INTERFACE
          ACLK                                : out STD_LOGIC;
          ARESETN                             : out STD_LOGIC_VECTOR(0 to 0);
          ------------------------------------------------------------------------------------
          -- PS2PL-DMA AXI4-STREAM MASTER INTERFACE TO ACCELERATOR AXI4-STREAM SLAVE INTERFACE
          M_AXIS_TO_ACCELERATOR_tdata         : out STD_LOGIC_VECTOR(7 downto 0);
          M_AXIS_TO_ACCELERATOR_tkeep         : out STD_LOGIC_VECTOR( 0    to 0);
          M_AXIS_TO_ACCELERATOR_tlast         : out STD_LOGIC;
          M_AXIS_TO_ACCELERATOR_tready        : in  STD_LOGIC;
          M_AXIS_TO_ACCELERATOR_tvalid        : out STD_LOGIC;
          ------------------------------------------------------------------------------------
          -- ACCELERATOR AXI4-STREAM MASTER INTERFACE TO PL2P2-DMA AXI4-STREAM SLAVE INTERFACE
          S_AXIS_S2MM_FROM_ACCELERATOR_tdata  : in  STD_LOGIC_VECTOR(31 downto 0);
          S_AXIS_S2MM_FROM_ACCELERATOR_tkeep  : in  STD_LOGIC_VECTOR( 3 downto 0);
          S_AXIS_S2MM_FROM_ACCELERATOR_tlast  : in  STD_LOGIC;
          S_AXIS_S2MM_FROM_ACCELERATOR_tready : out STD_LOGIC;
          S_AXIS_S2MM_FROM_ACCELERATOR_tvalid : in  STD_LOGIC
         );
  end component design_1_wrapper;

------------------------------------------
-- DEBAYERING FILTER COMPONENT DECLARATION 
component debayer_filter is
    generic (
        N : integer := 32
    );
    port (
        clk            : in  std_logic;
        rst_n          : in  std_logic;
        pixel          : in  std_logic_vector(7 downto 0);
        valid_in       : in  std_logic;
        new_image      : in  std_logic;

        R              : out std_logic_vector(7 downto 0);
        G              : out std_logic_vector(7 downto 0);
        B              : out std_logic_vector(7 downto 0);
        valid_out      : out std_logic;

        dbg_row_center : out integer range 0 to N-1;
        dbg_col_center : out integer range 0 to N-1;
        image_finished   : out std_logic 
    );
end component;

-------------------------------------------
-- INTERNAL SIGNAL & COMPONENTS DECLARATION

  signal aclk    : std_logic;
  signal aresetn : std_logic_vector(0 to 0);

  -- data path 
  signal tmp_tdata     : std_logic_vector(7 downto 0);
  signal R             : std_logic_vector(7 downto 0);
  signal G             : std_logic_vector(7 downto 0);
  signal B             : std_logic_vector(7 downto 0);
  signal tmp_tdata_32  : std_logic_vector(31 downto 0); -- 00RRGGBB

  --signal tmp_tkeep  : std_logic_vector(0 downto 0);
  --signal tmp_tlast  : std_logic;
  --signal tmp_tready : std_logic;
  --signal tmp_tvalid : std_logic;

  -- axi stream handshaking
  signal tmp_tvalid_in      : std_logic;
  signal tmp_tready_slave   : std_logic;
  signal tmp_tvalid_out     : std_logic;
  signal tmp_tready_master  : std_logic;

  -- flow control 
  signal tmp_tlast_PS2PL : std_logic;
  signal tmp_tlast_PL2PS : std_logic;

  signal new_image : std_logic;
  signal delay : std_logic := '0';

begin

  tmp_tready_slave  <= '1';
  tmp_tdata_32      <= "00000000" & R & G & B; 


  PROCESSING_SYSTEM_INSTANCE : design_1_wrapper
    port map (
              DDR_cas_n         => DDR_cas_n,
              DDR_cke           => DDR_cke,
              DDR_ck_n          => DDR_ck_n,
              DDR_ck_p          => DDR_ck_p,
              DDR_cs_n          => DDR_cs_n,
              DDR_reset_n       => DDR_reset_n,
              DDR_odt           => DDR_odt,
              DDR_ras_n         => DDR_ras_n,
              DDR_we_n          => DDR_we_n,
              DDR_ba            => DDR_ba,
              DDR_addr          => DDR_addr,
              DDR_dm            => DDR_dm,
              DDR_dq            => DDR_dq,
              DDR_dqs_n         => DDR_dqs_n,
              DDR_dqs_p         => DDR_dqs_p,
              FIXED_IO_mio      => FIXED_IO_mio,
              FIXED_IO_ddr_vrn  => FIXED_IO_ddr_vrn,
              FIXED_IO_ddr_vrp  => FIXED_IO_ddr_vrp,
              FIXED_IO_ps_srstb => FIXED_IO_ps_srstb,
              FIXED_IO_ps_clk   => FIXED_IO_ps_clk,
              FIXED_IO_ps_porb  => FIXED_IO_ps_porb,
              --------------------------------------------------------------------------
              ----------------------------------------------- PL (FPGA) COMMON INTERFACE
              ACLK                                => aclk,    -- clock to accelerator
              ARESETN                             => aresetn, -- reset to accelerator, active low
              ------------------------------------------------------------------------------------
              -- PS2PL-DMA AXI4-STREAM MASTER INTERFACE TO ACCELERATOR AXI4-STREAM SLAVE INTERFACE
              M_AXIS_TO_ACCELERATOR_tdata         => tmp_tdata,
              M_AXIS_TO_ACCELERATOR_tkeep         => open,
              M_AXIS_TO_ACCELERATOR_tlast         => tmp_tlast_PS2PL,
              M_AXIS_TO_ACCELERATOR_tready        => tmp_tready_slave,
              M_AXIS_TO_ACCELERATOR_tvalid        => tmp_tvalid_in,
              ------------------------------------------------------------------------------------
              -- ACCELERATOR AXI4-STREAM MASTER INTERFACE TO PL2P2-DMA AXI4-STREAM SLAVE INTERFACE
              S_AXIS_S2MM_FROM_ACCELERATOR_tdata  => tmp_tdata_32,
              S_AXIS_S2MM_FROM_ACCELERATOR_tkeep  => "1111",
              S_AXIS_S2MM_FROM_ACCELERATOR_tlast  => tmp_tlast_PL2PS,
              S_AXIS_S2MM_FROM_ACCELERATOR_tready => tmp_tready_master,
              S_AXIS_S2MM_FROM_ACCELERATOR_tvalid => tmp_tvalid_out
             );

  ACCELERATOR : debayer_filter
    port map (
      clk            => aclk,
      rst_n          => aresetn(0),
      
      new_image      => new_image,
      pixel          => tmp_tdata,
      valid_in       => tmp_tvalid_in,
      R              => R,
      G              => G,
      B              => B,
      
      valid_out      => tmp_tvalid_out,
      image_finished => tmp_tlast_PL2PS,

      dbg_row_center => open,
      dbg_col_center => open
    );

----------------------------
-- COMPONENTS INSTANTIATIONS

process(aclk)
begin 
    if (rising_edge(aclk)) then 
      delay <= tmp_tvalid_in;
      if tmp_tvalid_in = '1' and delay = '0' then 
          new_image <= '1';
      else 
          new_image <= '0';
      end if;
    end if; 

end process;
end architecture; -- arch