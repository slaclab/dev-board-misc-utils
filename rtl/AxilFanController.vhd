-------------------------------------------------------------------------------
-- File       : AxilFanController.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Axi-Lite interface for fan controller
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
use ieee.math_real.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity AxilFanController is
   generic (
      TPD_G              : time := 1 ns;
      SYSMON_BASE_ADDR_G : slv(31 downto 0);
      TEMP_OFF_G         : slv(31 downto 0) := x"0000_0400";
      AXIL_FREQ_G        : real
   );
   port (
      axilClk            : in  sl;
      axilRst            : in  sl;
      mAxilReadMaster    : out AxiLiteReadMasterType;
      mAxilReadSlave     : in  AxiLiteReadSlaveType;
      sAxilReadMaster    : in  AxiLiteReadMasterType;
      sAxilReadSlave     : out AxiLiteReadSlaveType;
      sAxilWriteMaster   : in  AxiLiteWriteMasterType;
      sAxilWriteSlave    : out AxiLiteWriteSlaveType;

      sysmonAlarm        : in  sl := '1';
      fanPwm             : out sl
   );
end entity AxilFanController;

architecture Impl of AxilFancontroller is

   function temp2adc(temp : real) return unsigned is
   begin
      return to_unsigned( integer(ieee.math_real.round((temp + 273.8195)/502.9098*65536)), 16);
   end function temp2adc;

   constant DEF_TEMP_C     : real := 50.0;

   constant DEF_ADC_C      : slv(15 downto 0) := slv( temp2adc( DEF_TEMP_C ) );

   -- the default preshift of 4 maxes out the 16-bit range at ~81deg
   -- with a target-temperature of 50deg:
   --   ((81-50)/503*2^16) << 4 = 64624
   constant DEF_PRESHIFT_C : slv( 3 downto 0) := toSlv(   4, 4);
   constant DEF_BYPASS_C   : sl               := '1';
   constant DEF_SPEED_C    : slv( 3 downto 0) := (others => '1');
   constant DEF_KP_C       : slv( 6 downto 0) := toSlv(  60, 7);

   type RegType is record
      r1         : slv(31 downto 0);
      rdSlv      : AxiLiteReadSlaveType;
      wrSlv      : AxiLiteWriteSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      r1       => DEF_ADC_C & DEF_PRESHIFT_C & DEF_SPEED_C & DEF_BYPASS_C & DEF_KP_C,
      rdSlv    => AXI_LITE_READ_SLAVE_INIT_C,
      wrSlv    => AXI_LITE_WRITE_SLAVE_INIT_C
   );

   signal r              : RegType := REG_INIT_C;
   signal rin            : RegType;

   signal monTemp        : slv(15 downto 0);
   signal ovr            : sl;
   
begin

   P_COMB : process ( r, sAxilReadMaster, sAxilWriteMaster, monTemp, sysmonAlarm, ovr ) is
      variable v    : RegType;
      variable ep   : AxiLiteEndPointType;
      variable r1   : slv(31 downto 0);
   begin
      v := r;

      axiSlaveWaitTxn(ep, sAxilWriteMaster, sAxilReadMaster, v.wrSlv, v.rdSlv);

      axiSlaveRegisterR(ep, X"0", 0, x"000" & "00" & ovr & sysmonAlarm & monTemp);

      axiSlaveRegister (ep, X"4", 0, v.r1);

      axiSlaveDefault(ep, v.wrSlv, v.rdSlv, AXI_RESP_DECERR_C);

      rin <= v;
   end process P_COMB;

   U_CTLR : entity work.FanController
      generic map (
         TPD_G              => TPD_G,
         SYSMON_BASE_ADDR_G => SYSMON_BASE_ADDR_G,
         TEMP_OFF_G         => TEMP_OFF_G,
         AXIL_FREQ_G        => AXIL_FREQ_G
      )
      port map (
         axilClk            => axilClk,
         axilRst            => axilRst,
         axilReadMaster     => mAxilReadMaster,
         axilReadSlave      => mAxilReadSlave,

         kp                 => r.r1( 6 downto  0),
         preshift           => r.r1(15 downto 12),
         speed              => r.r1(11 downto  8),
         bypass             => r.r1(7),
         refTemp            => r.r1(31 downto 16),
         
         sysmonAlarm        => sysmonAlarm,
         monTemp            => monTemp,
         multOverrange      => ovr,
         fanPwm             => fanPwm
      );

   P_SEQ : process (axilClk) is
   begin
      if ( rising_edge( axilClk ) ) then
         if ( axilRst = '1' ) then
            r <= REG_INIT_C;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process P_SEQ;

   sAxilReadSlave  <= r.rdSlv;
   sAxilWriteSlave <= r.wrSlv;

end architecture Impl;
