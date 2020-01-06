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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiLiteMasterPkg.all;
use surf.I2cPkg.all;

library dev_board_misc_utils;

library unisim;
use unisim.vcomponents.all;

entity TimingClkSwitcherTb is
end entity TimingClkSwitcherTb;

architecture impl of TimingClkSwitcherTb is

   constant AS_C       : natural := 1;
   constant DS_C       : natural := 1;
   constant AB_C       : natural := 8*AS_C;
   constant DB_C       : natural := 8*DS_C;
   constant I2C_SLV_C  : slv     := "1110100";
   constant I2C_ADDR_C : natural := to_integer(unsigned(I2C_SLV_C));

   constant TPD_C      : time    := 0 ns;

   constant DEVMAP_C   : I2cAxiLiteDevArray := (
      0 => MakeI2cAxiLiteDevType( I2C_SLV_C, 8, 1, '1' ),
      1 => MakeI2cAxiLiteDevType( I2C_SLV_C, 8, 8, '1' )
   );

   signal rama         : slv(AB_C-1 downto 0);
   signal wdat         : slv(DB_C-1 downto 0);
   signal rdat         : slv(DB_C-1 downto 0) := x"a5";
   signal ren          : sl;
   signal wen          : sl;
   signal i2ci         : i2c_in_type;
   signal i2co         : i2c_out_type;

   signal iicClk       : sl := '0';

   signal scl, sda     : sl;

   signal axilClk      : sl := '0';
   signal axilRst      : sl := '1';

   signal arm          : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal ars          : AxiLiteReadSlaveType;
   signal awm          : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal aws          : AxiLiteWriteSlaveType;

   signal bsy          : sl   := '0';

   constant HP         : time := 5 ns;

   signal txRst        : sl;
   signal clkSel       : sl := '1';
   signal txRstReg     : sl := '0';

   signal count        : integer := 0;
   signal bsyDelay     : natural := 0;

   signal running      : boolean := true;

   type   RegArray is array (natural range 7 to 12) of slv(DB_C - 1 downto 0);

   signal r7to12       : RegArray := (
      7 => ("000" &  "00001"),
      8 => ("11"  & "000010"),
      9  => x"BC",
      10 => x"01",
      11 => x"1E",
      12 => x"B9"
   );

   signal r135         : slv(DB_C - 1 downto 0) := (others => '0');
   signal r137         : slv(DB_C - 1 downto 0) := (others => '0');


begin

   P_WR : process ( axilClk ) is
      variable a    : natural;
      variable v135 : slv(r135'range);
      variable dly  : natural;
   begin
      if ( rising_edge( axilClk ) ) then
         v135 := r135;
         dly  := bsyDelay;
         a    := to_integer(unsigned(rama));
         if ( wen = '1' ) then
           case ( a ) is
             when 135 =>
               v135 := wdat;
               if ( wdat(0) = '1' ) then
                  dly := 100;
               else
                  v135(0) := r135(0); -- canot reset
               end if;

             when 137 =>
               r137 <= wdat;

             when 7|8|9|10|11|12 =>
               r7to12(a) <= wdat;

             when others =>
           end case;
         end if;

         if ( bsyDelay /= 0 ) then
            dly := bsyDelay - 1;
            if (dly = 0) then 
               v135(0) := '0';
            end if;
         end if;

         bsyDelay <= dly;
         r135     <= v135;
      end if;
   end process P_WR;

   bsy <= r135(0);

   P_RD : process( rama, r7to12, r135, r137 ) is
      variable v : slv(rdat'range);
      variable a : natural;
   begin
      v := x"A5";
      a := to_integer(unsigned(rama));
      case ( a ) is 
         when 135 => v := r135;
         when 137 => v := r137;

         when 7|8|9|10|11|12 =>
            v := r7to12(a);

         when others=>
      end case;
      rdat <= v;
   end process P_RD;


   U_DUT : entity dev_board_misc_utils.TimingClkSwitcher(TimingClkSwitcherSi570)
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

   U_I2CM : entity surf.AxiI2cRegMaster
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

   sda <= 'H';
   scl <= 'H';

   U_Slv : entity surf.I2cRegSlave
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

   P_CHECKER : process (axilClk) is
   begin
      if ( rising_edge( axilClk ) ) then
         txRstReg <= txRst;
         if ( txRst = '0' and txRstReg = '1' ) then
            if ( clkSel = '1' ) then
               assert r7to12( 7) = x"60" severity failure;
               assert r7to12( 8) = x"42" severity failure;
               assert r7to12( 9) = x"d8" severity failure;
               assert r7to12(10) = x"01" severity failure;
               assert r7to12(11) = x"2a" severity failure;
               assert r7to12(12) = x"31" severity failure;
               clkSel <= '0';
            else
               assert r7to12( 7) = x"E0" severity failure;
               assert r7to12( 8) = x"42" severity failure;
               assert r7to12( 9) = x"dd" severity failure;
               assert r7to12(10) = x"0b" severity failure;
               assert r7to12(11) = x"69" severity failure;
               assert r7to12(12) = x"b2" severity failure;
               running <= false;
            end if;
         end if;
      end if;
   end process P_CHECKER;

end architecture impl;
