-------------------------------------------------------------------------------
-- File       : FanController.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Proportional controller for the fan.
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
use work.AxiLiteSequencerPkg.all;

--
-- fan speed is controlled by proportional feedback:
--
--    a   = (temp_adc - temp_ref) << preshift
--    if ( a >= 1<<7 )
--      pwm = 1.0
--    else
--      pwm = (( a * kp ) >> 7) / 2^7
--
-- Since the multiplier computes only the upper-half (7 bits) of the
-- 7x7-bit result the 'preshift' can be used to scale small differences.
--
-- The feedback can be bypassed by setting 'bypass' and the desired
-- speed (4-bits). Note that 'sysmonAlarm' overrides the feedback 
-- (whether bypassed or not) and asserts full-speed.
--
entity FanController is
   generic (
      TPD_G              : time := 1 ns;
      SYSMON_BASE_ADDR_G : slv(31 downto 0);
      TEMP_OFF_G         : slv(31 downto 0) := x"0000_0400";
      AXIL_FREQ_G        : real
   );
   port (
      axilClk            : in  sl;
      axilRst            : in  sl;
      axilReadMaster     : out AxiLiteReadMasterType;
      axilReadSlave      : in  AxiLiteReadSlaveType;
      kp                 : in  slv( 6 downto 0);
      preshift           : in  slv( 3 downto 0);
      speed              : in  slv( 3 downto 0) := (others => '1');
      bypass             : in  sl := '0';
      refTemp            : in  slv(15 downto 0);
      sysmonAlarm        : in  sl := '1';
      monTemp            : out slv(15 downto 0); -- temp. ADC readback
      fanPwm             : out sl
   );
end entity FanController;

architecture Impl of Fancontroller is

   constant BASE_C       : unsigned(31 downto 0) := unsigned(SYSMON_BASE_ADDR_G);
   constant OFF_C        : unsigned(31 downto 0) := unsigned(TEMP_OFF_G);

   constant PROG_C       : AxiLiteProgramArray := (
      0 => axiLiteReadInst( slv(BASE_C + OFF_C), true )
   );

   constant PWM_W_C      : positive :=  4;

   constant FB_FREQ_C    : real     := 10.0;
   constant PWM_FREQ_C   : real     := 100.0;

   constant FB_DIV_C     : positive := positive(AXIL_FREQ_G/FB_FREQ_C) - 1;

   constant PWM_PRESC_C  : natural  := natural(round(AXIL_FREQ_G/PWM_FREQ_C/2.0**real(PWM_W_C)));

   constant MULU_W_C     : positive :=  7;
   constant TEMP_W_C     : positive := 16;

   subtype PeriodType is natural range 0 to FB_DIV_C;
   subtype ShiftType  is natural range 0 to TEMP_W_C - 1;

   type StateType is (IDLE, RDBK, SHFT, MULT);

   type RegType is record
      state   : StateType;
      delTemp : unsigned(TEMP_W_C  - 1 downto 0);
      temp    : unsigned(15 downto 0);
      period  : PeriodType;
      shift   : ShiftType;
      trgRdbk : sl;
      trgMul  : sl;
      pw      : unsigned(PWM_W_C   - 1 downto 0);
      ovr     : sl;
   end record;

   constant REG_INIT_C : RegType := (
      state   => IDLE,
      delTemp => (others => '0'),
      temp    => (others => '0'),
      period  => 0,
      shift   => 0,
      trgRdbk => '0',
      trgMul  => '0',
      pw      => (others => '0'),
      ovr     => '1' -- fan initially on
   );

   signal rdbkDon        : sl;
   signal tempReadback   : slv(31 downto 0);
   signal prod           : unsigned(MULU_W_C - 1 downto 0);
   signal mulDon         : sl;
   signal pwmOut         : sl;

   signal r              : RegType := REG_INIT_C;
   signal rin            : RegType;
   
begin

   P_COMB : process ( r, rdbkDon, tempReadback, prod, mulDon, refTemp, preshift, kp, bypass, speed ) is
      variable v    : RegType;
      variable t,ti : unsigned(TEMP_W_C - 1 downto 0);
   begin
      v := r;
      if ( r.period = FB_DIV_C ) then
         v.period := 0;
      else
         v.period := r.period + 1;
      end if;

      v.trgRdbk := '0';
      v.trgMul  := '0';

      case ( r.state ) is

         when IDLE =>

            if ( r.period = 0 ) then
               v.trgRdbk := '1';
               v.state   := RDBK;
            end if;
   
         when RDBK => 

            if ( rdbkDon = '1' or r.period = 0 ) then
               if ( rdbkDon = '1' ) then
                  v.temp := unsigned(tempReadback(15 downto 0));
                  t      := unsigned(tempReadback(TEMP_W_C - 1 downto 0));
                  ti     := unsigned(refTemp     (TEMP_W_C - 1 downto 0));
                  if ( t <= ti ) then
                     v.delTemp := (others => '0');
                  else
                     v.delTemp := t - ti;
                  end if;
                  v.shift := to_integer( unsigned(preshift) );
                  v.state := SHFT;
               else
                  -- no readback in a full feedback period!
                  v.temp  := (others => '1');
                  v.ovr   := '1';
                  v.state := IDLE;
               end if;
               if ( bypass = '1' ) then
                  v.pw    := unsigned( speed );
                  v.ovr   := '0';
                  v.state := IDLE;
               end if;
            end if;

         when SHFT =>

            if ( r.shift = 0 ) then
               v.trgMul := '1';
               v.state  := MULT;
               v.ovr    := '0';
            else
               if ( r.delTemp(TEMP_W_C - 1) = '1' ) then
                  v.ovr     := '1';
                  v.state   := IDLE;
               else
                  v.shift   := r.shift - 1;
                  v.delTemp := r.delTemp(TEMP_W_C - 2 downto 0) & '0';
               end if;
            end if;

         when MULT => 

            if ( mulDon = '1' ) then
               v.state := IDLE;
               v.pw    := prod(MULU_W_C - 1 downto MULU_W_C - PWM_W_C);
            end if;

      end case;

      rin <= v;
   end process P_COMB;

   U_READ_TEMP : entity work.AxiLiteSequencer
      generic map (
         TPD_G           => TPD_G
      )
      port map (
         axilClk         => axilClk,
         axilRst         => axilRst,

         prog            => PROG_C,

         trg             => r.trgRdbk,

         pc              => 0,
         rs              => rdbkDon,
         don             => open,
         rdData          => tempReadback,

         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave
      );

   U_MULT : entity work.MuluSeq
      generic map (
         TPD_G           => TPD_G,
         WIDTH_G         => MULU_W_C
      )
      port map (
         clk             => axilClk,
         rst             => axilRst,
         trg             => r.trgMul,
         a               => r.delTemp(TEMP_W_C - 1 downto TEMP_W_C - MULU_W_C),
         b               => unsigned( kp(MULU_W_C - 1 downto 0) ),
         c               => to_unsigned( 0, MULU_W_C),
         p               => prod,
         don             => mulDon
      );

   U_PWM : entity work.PWMController
      generic map (
         TPD_G           => TPD_G,
         PRESC_G         => PWM_PRESC_C,
         WIDTH_G         => PWM_W_C
      )
      port map (
         clk             => axilClk,
         rst             => axilRst,
         pulseWidth      => r.pw,
         strobe          => open,
         modOut          => pwmOut
      );

   fanPwm  <= pwmOut or r.ovr or sysmonAlarm;
   monTemp <= slv( r.temp );

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

end architecture Impl;
