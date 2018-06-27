-------------------------------------------------------------------------------
-- File       : TimingClkSwitcherTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Testbeed for TimingClkSwitcher
-------------------------------------------------------------------------------
-- This file is part of 'Development Board Misc. Utilities Library'
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'Development Board Misc. Utilities Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.TextUtilPkg.all;
use work.AxiLitePkg.all;
use work.AxiLiteMasterPkg.all;
use work.I2cPkg.all;

library unisim;
use unisim.vcomponents.all;

entity TimingClkSwitcherSi5328Tb is
end entity TimingClkSwitcherSi5328Tb;

architecture impl of TimingClkSwitcherSi5328Tb is

   constant AS_C       : natural := 1;
   constant DS_C       : natural := 1;
   constant AB_C       : natural := 8*AS_C;
   constant DB_C       : natural := 8*DS_C;
   constant I2C_SLV_C  : slv     := "1110100";
   constant I2C_SLVM_C : slv     := "1110101";
   constant I2C_ADDR_C : natural := to_integer(unsigned(I2C_SLV_C));

   constant TPD_C      : time    := 0 ns;

   constant DEVMAP_C   : I2cAxiLiteDevArray := (
      0 => MakeI2cAxiLiteDevType( I2C_SLVM_C, 8, 1, '1' ),
      1 => MakeI2cAxiLiteDevType( I2C_SLV_C, 8, 8, '1' )
   );

   signal rama         : slv(AB_C-1 downto 0);
   signal wdat         : slv(DB_C-1 downto 0);
   signal wdatTca      : slv(DB_C-1 downto 0);
   signal rdatTca      : slv(DB_C-1 downto 0) := x"00";
   signal rdat         : slv(DB_C-1 downto 0) := x"a5";
   signal ren          : sl;
   signal renTca       : sl;
   signal wen          : sl;
   signal wenTca       : sl;
   signal i2ci         : i2c_in_type;
   signal i2co         : i2c_out_type;
   signal i2ciTca      : i2c_in_type;
   signal i2coTca      : i2c_out_type;

   signal iicClk       : sl := '0';

   signal scl, sda     : sl;

   signal axilClk      : sl := '0';
   signal axilRst      : sl := '1';

   signal arm          : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal ars          : AxiLiteReadSlaveType;
   signal awm          : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal aws          : AxiLiteWriteSlaveType;

   constant HP         : time := 5 ns;

   signal txRst        : sl;
   signal clkSel       : sl := '1';
   signal clkSelLst    : sl := '0';
   signal txRstReg     : sl := '0';

   signal count        : integer := 0;

   signal running      : boolean := true;

   type   RegArray is array (natural range <>) of slv(DB_C - 1 downto 0);

   signal regs : RegArray( 0 to 255 ) := (others => (others => '0'));

begin

   P_WR : process ( axilClk ) is
      variable a    : natural;
   begin
      if ( rising_edge( axilClk ) ) then
         a    := to_integer(unsigned(rama));
         if ( wen = '1' ) then
           case ( a ) is
             when 0|1|2|3|5|6|7|21|25|31|32|33|34|35|36|40|41|42|43|44|45|46|47|48|55|136 =>
               regs(a) <= wdat;

             when others =>
           end case;
         end if;
      end if;
   end process P_WR;

   P_RD : process( rama, regs ) is
      variable v : slv(rdat'range);
      variable a : natural;
   begin
      v := x"a5";
      a := to_integer(unsigned(rama));
      case ( a ) is 
         when 0|1|2|3|5|6|7|21|25|31|32|33|34|35|36|40|41|42|43|44|45|46|47|48|55|136 =>
            v := regs(a);

         when others=>
      end case;
      rdat <= v;
   end process P_RD;


   U_DUT : entity work.TimingClkSwitcher(TimingClkSwitcherSi5328)
      generic map (
         TPD_G                  => TPD_C,
         CLOCK_AXIL_BASE_ADDR_G => x"0000_0400",
         TCASW_AXIL_BASE_ADDR_G => x"0000_0000",
         AXIL_FREQ_G            => 6.0E2
      )
      port map (
         axilClk         => axilClk,
         axilRst         => axilRst,

         clkSel          => clkSel,

         txRst           => txRst,

         mAxilWriteMaster => awm,
         mAxilWriteSlave  => aws,
         mAxilReadMaster  => arm,
         mAxilReadSlave   => ars
      );

   P_CLK : process is
   begin
      if ( running ) then
         axilClk <= not axilClk;
         iicClk  <= not iicClk;
         wait for HP;
         axilClk <= not axilClk;
         wait for HP;
         axilClk <= not axilClk;
         wait for HP;
         axilClk <= not axilClk;
         wait for HP;
         axilClk <= not axilClk;
         wait for HP;
      else
         report "TEST PASSED";
         wait;
      end if;
   end process P_CLK;

   P_CNT : process(axilClk) is
   variable c: integer;
   begin
      if ( rising_edge(axilClk) ) then
         c := count + 1;
         case count is
           when 15    =>
              axilRst <= '0';
 --          when 30    => running <= false;
           when others =>
         end case;
         count <= c;
      end if;
   end process P_CNT;

   U_I2CM : entity work.AxiI2cRegMaster
      generic map (
         TPD_G           => TPD_C,
         DEVICE_MAP_G    => DEVMAP_C,
         I2C_SCL_FREQ_G  => 1.0,
         I2C_MIN_PULSE_G => 0.1,
         AXI_CLK_FREQ_G  => 20.0
      )
      port map
      (
         scl             => scl,
         sda             => sda,

         axiReadMaster   => arm,
         axiReadSlave    => ars,
         axiWriteMaster  => awm,
         axiWriteSlave   => aws,

         axiClk          => axilClk,
         axiRst          => axilRst
      );

   U_SCLBUF : IOBUF
      port map (
         IO => scl,
         I  => i2co.scl,
         T  => i2co.scloen,
         O  => i2ci.scl
      );

   U_SDABUF : IOBUF
      port map (
         IO => sda,
         I  => i2co.sda,
         T  => i2co.sdaoen,
         O  => i2ci.sda
      );

   -- make sure the mux is set when talking to the clock
   P_MUX_CHECKER : process ( i2co, i2ci, rdatTca, axilRst ) is
   begin
      if ( (i2co.sdaoen = '0' or i2co.scloen = '0') ) then
         --  Attempting to write to slave but MUX not set!
         assert rdatTca(4) = '1' severity failure;
      end if;
   end process P_MUX_CHECKER;

   U_SCLBUFM : IOBUF
      port map (
         IO => scl,
         I  => i2coTca.scl,
         T  => i2coTca.scloen,
         O  => i2ciTca.scl
      );

   U_SDABUFM : IOBUF
      port map (
         IO => sda,
         I  => i2coTca.sda,
         T  => i2coTca.sdaoen,
         O  => i2ciTca.sda
      );


   sda <= 'H';
   scl <= 'H';

   U_Slv : entity work.I2cRegSlave
      generic map (
         TPD_G       => TPD_C,
         I2C_ADDR_G  => I2C_ADDR_C,
         ADDR_SIZE_G => AS_C,
         FILTER_G    => 2
      )
      port map (
         clk    => axilClk,

         addr   => rama, 
         wrEn   => wen,
         wrData => wdat,
         rdEn   => ren,
         rdData => rdat,

         i2ci   => i2ci,
         i2co   => i2co
      );

   U_Tca : entity work.I2cRegSlave
      generic map (
         TPD_G       => TPD_C,
         I2C_ADDR_G  => (I2C_ADDR_C+1),
         ADDR_SIZE_G => 1,
         FILTER_G    => 2
      )
      port map (
         clk    => axilClk,

         addr   => open,
         wrEn   => wenTca,
         wrData => wdatTca,
         rdEn   => renTca,
         rdData => rdatTca,

         i2ci   => i2ciTca,
         i2co   => i2coTca
      );

   P_MUX : process (axilClk) is
   begin
      if ( rising_edge( axilClk ) ) then
         if ( clkSelLst /= clkSel ) then
           rdatTca   <= (others => '0');
           clkSelLst <= clkSel;
           report "TCA Mux Reset (clkSel changed)";
         elsif ( wenTca = '1' ) then
           rdatTca <= wdatTca;
           report "TCA Mux Written: str(wdatTca)";
         end if;
      end if;
   end process P_MUX;


   P_CHECKER : process (axilClk) is
   begin
      if ( rising_edge( axilClk ) ) then
         txRstReg <= txRst;
         if ( txRst = '0' and txRstReg = '1' ) then

            assert regs(  0 ) = x"54" severity failure;
            assert regs(  1 ) = x"e5" severity failure;
            assert regs(  3 ) = x"55" severity failure;
            assert regs(  5 ) = x"2d" severity failure;
            assert regs(  6 ) = x"3f" severity failure;
            assert regs(  7 ) = x"28" severity failure;
            assert regs( 21 ) = x"fc" severity failure;
            assert regs( 55 ) = x"1c" severity failure;
            assert regs(136 ) = x"40" severity failure;

            if ( clkSel = '1' ) then
               assert regs(  2 ) =  x"52" severity failure;
               assert regs( 25 ) =  x"60" severity failure;
               assert regs( 31 ) =  x"00" severity failure;
               assert regs( 32 ) =  x"00" severity failure;
               assert regs( 33 ) =  x"01" severity failure;
               assert regs( 34 ) =  x"00" severity failure;
               assert regs( 35 ) =  x"00" severity failure;
               assert regs( 36 ) =  x"01" severity failure;
               assert regs( 40 ) =  x"20" severity failure;
               assert regs( 41 ) =  x"48" severity failure;
               assert regs( 42 ) =  x"d5" severity failure;
               assert regs( 43 ) =  x"00" severity failure;
               assert regs( 44 ) =  x"08" severity failure;
               assert regs( 45 ) =  x"00" severity failure;
               assert regs( 46 ) =  x"00" severity failure;
               assert regs( 47 ) =  x"08" severity failure;
               assert regs( 48 ) =  x"00" severity failure;

               clkSel <= '0';
            else
               assert regs(  2 ) = x"62" severity failure;
               assert regs( 25 ) = x"e0" severity failure;
               assert regs( 31 ) = x"00" severity failure;
               assert regs( 32 ) = x"00" severity failure;
               assert regs( 33 ) = x"01" severity failure;
               assert regs( 34 ) = x"00" severity failure;
               assert regs( 35 ) = x"00" severity failure;
               assert regs( 36 ) = x"01" severity failure;
               assert regs( 40 ) = x"00" severity failure;
               assert regs( 41 ) = x"38" severity failure;
               assert regs( 42 ) = x"af" severity failure;
               assert regs( 43 ) = x"00" severity failure;
               assert regs( 44 ) = x"04" severity failure;
               assert regs( 45 ) = x"f2" severity failure;
               assert regs( 46 ) = x"00" severity failure;
               assert regs( 47 ) = x"04" severity failure;
               assert regs( 48 ) = x"f2" severity failure;

               running <= false;
            end if;
         end if;
      end if;
   end process P_CHECKER;

end architecture impl;
