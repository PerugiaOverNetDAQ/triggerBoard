--!@file top_triggerBoard.vhd
--!@author Mattia Barbanera, mattia.barbanera@infn.it

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.intel_package.all;
use work.basic_package.all;


--!@copydoc top_triggerBoard.vhd
entity top_triggerBoard is
  generic (
    --HoG: Global Generic Variables
    GLOBAL_DATE : std_logic_vector(31 downto 0) := (others => '0');
    GLOBAL_TIME : std_logic_vector(31 downto 0) := (others => '0');
    GLOBAL_VER  : std_logic_vector(31 downto 0) := (others => '0');
    GLOBAL_SHA  : std_logic_vector(31 downto 0) := (others => '0');
    TOP_VER     : std_logic_vector(31 downto 0) := (others => '0');
    TOP_SHA     : std_logic_vector(31 downto 0) := (others => '0');
    CON_VER     : std_logic_vector(31 downto 0) := (others => '0');
    CON_SHA     : std_logic_vector(31 downto 0) := (others => '0');
    HOG_VER     : std_logic_vector(31 downto 0) := (others => '0');
    HOG_SHA     : std_logic_vector(31 downto 0) := (others => '0');

    --HoG: Project Specific Lists (One for each .src file in your Top/ folder)
    TRIGGERBOARD_SHA : std_logic_vector(31 downto 0) := (others => '0');
    TRIGGERBOARD_VER : std_logic_vector(31 downto 0) := (others => '0')
    );
  port(
    --- CLOCK ------------------------------------------------------------------
    FPGA_CLK1_50 : in std_logic;
    FPGA_CLK2_50 : in std_logic;
    FPGA_CLK3_50 : in std_logic;

    --- KEY --------------------------------------------------------------------
    KEY : in std_logic_vector(1 downto 0);

    --- LED --------------------------------------------------------------------
    LED : out std_logic_vector(7 downto 0);

    --- SW ---------------------------------------------------------------------
    SW : in std_logic_vector(3 downto 0);

    --- GPIO -------------------------------------------------------------------
    GPIO_0    : out std_logic_vector(35 downto 0);

    iGND      : in  std_logic_vector(6 downto 0);
    oGND      : out std_logic_vector(9 downto 0);

    iCLK_PP   : in  std_logic;
    iSE_BUSY  : in  std_logic_vector(5 downto 0);
    iTRG_LEMO : in  std_logic;
    iTRG_PP   : in  std_logic;
    iRST_PP   : in  std_logic;
    iGP       : in  std_logic_vector(1 downto 0);
    oGP       : out std_logic;
    oTRIG     : out std_logic;
    oBCO_CLK  : out std_logic;
    oBCO_RST  : out std_logic;
    oMUX_SEL  : out std_logic;        --!MUX selector: 0->LVDS, 1->FPGA 
    oI2C_SDA  : out std_logic;
    oI2C_SCL  : out std_logic
    );
end entity top_triggerBoard;

--!@copydoc top_triggerBoard.vhd
architecture std of top_triggerBoard is
  signal sClk    : std_logic;           -- FPGA clock
  signal sKeys   : std_logic_vector(1 downto 0);
  signal sKeys_n : std_logic_vector(1 downto 0);
  signal sSw     : std_logic_vector(3 downto 0);

  -- Internal BCOClk Counter
  signal sBcoClkEn  : std_logic;
  signal sBcoClkRst : std_logic;
  signal sBcoClk    : std_logic;

  --
  signal sClkPp   : std_logic;
  signal sTrgLemo : std_logic;
  signal sTrgPp   : std_logic;
  signal sRstPp   : std_logic;
  signal sBusyPp  : std_logic_vector(iSE_BUSY'length-1 downto 0);
  signal sGp      : std_logic_vector(iGP'length-1 downto 0);

begin
  sClk <= FPGA_CLK1_50;

  sBcoClkEn  <= sSw(0);
  sBcoClkRst <= sKeys(0);
  --!@brief Clock divider to generate 1 MHz BCO clock
  BCO_CLK_DIV : clock_divider
    generic map(
      pPOLARITY => '1'
      )
    port map(
      iCLK        => sClk,
      iRST        => sBcoClkRst,
      iEN         => sBcoClkEn,
      iFREQ_DIV   => x"0032",
      iDUTY_CYCLE => x"0019",
      oCLK_OUT    => sBcoClk
      );


  --- I/O synchronization and buffering ----------------------------------------
  LED(7 downto 6) <= "00";
  LED(5 downto 0) <= sBusyPp;

  GPIO_0   <= (others => '0');
  oGND     <= (others => '0');
  oBCO_RST <= '0';
  oMUX_SEL <= '0';
  oI2C_SDA <= '0';
  oI2C_SCL <= '0';

  FFD_PROC : process(sClk)
  begin
    if (rising_edge(sClk)) then
      oBCO_CLK <= sBcoClk;
      oGP      <= sBcoClk;
      oTRIG    <= sTrgLemo;
    end if;
  end process;

  CLK_PP_SYNCH : sync_edge
    generic map (
      pSTAGES => 3
      )
    port map (
      iCLK => sClk,
      iRST => '0',
      iD   => iCLK_PP,
      oQ   => sClkPp
      );

  TRG_LEMO_SYNCH : sync_edge
    generic map (
      pSTAGES => 3
      )
    port map (
      iCLK => sClk,
      iRST => '0',
      iD   => iTRG_LEMO,
      oQ   => sTrgLemo
      );

  TRG_PP_SYNCH : sync_edge
    generic map (
      pSTAGES => 3
      )
    port map (
      iCLK => sClk,
      iRST => '0',
      iD   => iTRG_PP,
      oQ   => sTrgPp
      );

  RST_PP_SYNCH : sync_edge
    generic map (
      pSTAGES => 3
      )
    port map (
      iCLK => sClk,
      iRST => '0',
      iD   => iRST_PP,
      oQ   => sRstPp
      );

  BUSY_SYNCH_GEN : for I in 0 to iSE_BUSY'length-1 generate
    BUSY_PP_SYNCH : sync_edge
      generic map (
        pSTAGES => 3
        )
      port map (
        iCLK => sClk,
        iRST => '0',
        iD   => iSE_BUSY(I),
        oQ   => sBusyPp(I)
        );
  end generate BUSY_SYNCH_GEN;

  GP_SYNCH_GEN : for M in 0 to sGp'length-1 generate
    GP_SYNCH : sync_edge
      generic map (
        pSTAGES => 3
        )
      port map (
        iCLK => sClk,
        iRST => '0',
        iD   => iGP(M),
        oQ   => sGp(M)
        );
  end generate GP_SYNCH_GEN;

  sKeys <= not sKeys_n;
  --!@brief Debounce logic to clean out glitches within 1ms
  KEY_DEBOUNCE : debounce
    generic map(
      WIDTH         => 2,
      POLARITY      => "LOW",
      TIMEOUT       => 50000,  -- at 50Mhz this is a debounce time of 1ms
      TIMEOUT_WIDTH => 16               -- ceil(log2(TIMEOUT))
      )
    port map (
      clk      => sClk,
      reset_n  => '1',
      data_in  => KEY,
      data_out => sKeys_n
      );

  --!@brief Debounce logic to clean out glitches within 1ms
  SW_DEBOUNCE : debounce
    generic map(
      WIDTH         => 4,
      POLARITY      => "HIGH",
      TIMEOUT       => 50000,  -- at 50Mhz this is a debounce time of 1ms
      TIMEOUT_WIDTH => 16               -- ceil(log2(TIMEOUT))
      )
    port map (
      clk      => sClk,
      reset_n  => '1',
      data_in  => SW,
      data_out => sSw
      );

end architecture;
