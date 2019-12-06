-------------------------------------------------------------------------------
-- File       : FanControllerTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Testbed for FanController
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
use surf.TextUtilPkg.all;

library dev_board_misc_utils;

entity FanControllerTb is
end entity FanControllerTb;

architecture impl of FanControllerTb is
   constant PRE_C : positive:= 3;
   constant WID_C : positive:= 3;
   constant TPD_C : time    := 1 ns;

   function temp2adc(temp : real) return unsigned is
   begin
      return to_unsigned( integer(ieee.math_real.round((temp + 273.8195)/502.9098*65536)), 16);
   end function temp2adc;

   signal clk : std_logic := '0';

   signal run : boolean := true;

   signal cnt : natural   := 0;
   signal rst : std_logic := '1';

   signal pwm : std_logic;

   signal sm  : sl := '0';
   signal mArm : AxiLiteReadMasterType;
   signal mArs : AxiLiteReadSlaveType;
   signal sArm : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal sArs : AxiLiteReadSlaveType;
   signal sAwm : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal sAws : AxiLiteWriteSlaveType;

   signal kp  : slv( 6 downto 0) := toSlv( 127, 7 );
   signal ps  : slv( 3 downto 0) := toSlv(   4, 4 );
   signal ref : slv(15 downto 0) := slv( temp2adc( 50.0 ) );
   signal rbk : slv(31 downto 0) := x"0000" & slv( temp2adc( 60.0 ) );
   signal bps : sl               := '0';
   signal spd : slv( 3 downto 0) := x"f";

   constant RR_C : positive := 1;

   signal rr : Slv32Array(RR_C - 1  downto 0) := ( others => (others => '0') );

   signal arm : AxiLiteReadMasterType;

begin

   P_PROG : process is
      variable dat : slv(31 downto 0);
   begin
      wait until rst = '0';
      axiLiteBusSimWrite( clk, sAwm, sAws, x"0000_0004", ref & ps & spd & bps & kp );
      wait until cnt = 200;
      axiLiteBusSimRead ( clk, sArm, sArs, x"0000_0000", dat, true );
      print( str(dat) );
      wait;
   end process;

   P_CLK : process is
   begin
      if ( run ) then
         clk <= not clk;
         wait for 10 ns;
      else
         wait;
      end if;
   end process P_CLK;

   P_RUN : process(clk) is
      variable v : natural;
   begin
      if ( rising_edge( clk ) ) then
         v := cnt + 1;
         case cnt is
            when 2      =>
               rst <= '0' after TPD_C;
            when  40    =>
               bps <= '0' after TPD_C;
            when 10000    =>
               run <= false;
            when others =>
         end case;
         cnt <= v after TPD_C;
      end if;
   end process P_RUN;

   rr(0) <= rbk;

   U_DUT : entity dev_board_misc_utils.AxilFanController
      generic map (
         TPD_G              => TPD_C,
         SYSMON_BASE_ADDR_G => x"0000_0000",
         AXIL_FREQ_G        => 1600.0
      )
      port map (
         axilClk          => clk,
         axilRst          => rst,

         mAxilReadMaster  => mArm,
         mAxilReadSlave   => mArs,
         sAxilReadMaster  => sArm,
         sAxilReadSlave   => sArs,
         sAxilWriteMaster => sAwm,
         sAxilWriteSlave  => sAws,

         sysmonAlarm      => sm,
         fanPwm           => pwm
      );

   U_REGS : entity surf.AxiLiteRegs
      generic map (
         TPD_G          => TPD_C,
         NUM_READ_REG_G => RR_C
      )
      port map (
         axiClk         => clk,
         axiClkRst      => rst,
         axiReadMaster  => mArm,
         axiReadSlave   => mArs,
         axiWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axiWriteSlave  => open,
         readRegister   => rr
      );

end architecture impl;
