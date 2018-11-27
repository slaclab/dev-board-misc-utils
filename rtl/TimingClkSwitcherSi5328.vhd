-------------------------------------------------------------------------------
-- File       : TimingClkSwitcherSi5328.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Switch Timing GTH Si5328 Reference Clock
-------------------------------------------------------------------------------
-- This file is part of 'Development Board Misc. Utilities Library'
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'Development Board Misc. Utilities Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

-- State machine that 
--   1) Initializes the Si5328 (free-running mode)
--   2) monitors clkSel and switches the Si5328 to generate
--       2*1300/7 MHz when '1' ("LCLS-2" mode)
--       2*119    MHz when '0' ("LCLS-1" mode)
--      each time the state of clkSel changes.
--
-- The generated clock is used as a reference for an SFP/GTH transceiver 
-- for common-platform timing.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiLiteSequencerPkg.all;

architecture TimingClkSwitcherSi5328 of TimingClkSwitcher is

   function regOff(b : slv; o : natural) return slv is
      variable r : unsigned(b'range);
   begin
      r := unsigned(b) + shift_left(to_unsigned(o, 32),2);
      return slv(r);
   end function regOff;

   function clkWr(reg: natural; val: slv(7 downto 0); last: boolean := false) return AxiLiteInstructionType is
   begin
      return axiLiteWriteInst( regOff(CLOCK_AXIL_BASE_ADDR_G, reg), (x"0000_00" & val), last );
   end function clkWr;

   function clkRd(reg: natural; last: boolean := false) return AxiLiteInstructionType is
   begin
      return axiLiteReadInst( regOff(CLOCK_AXIL_BASE_ADDR_G, reg), last );
   end function clkRd;

   function tcaWr(val: slv(7 downto 0); last: boolean := false) return AxiLiteInstructionType is
   begin
      return axiLiteWriteInst( TCASW_AXIL_BASE_ADDR_G, (x"0000_00" & val), last );
   end function tcaWr;

   function tcaRd(last: boolean := false) return AxiLiteInstructionType is
   begin
      return axiLiteReadInst( TCASW_AXIL_BASE_ADDR_G, last );
   end function tcaRd;

   constant N1_HS_LCLS2_C:  slv( 2 downto 0) :=  "011";   -- => 7
   constant N1_HS_LCLS1_C:  slv( 2 downto 0) :=  "111";   -- => 11

   constant NC1_LS_LCLS2_C: slv(19 downto 0) := x"00001"; -- => 2
   constant NC1_LS_LCLS1_C: slv(19 downto 0) := x"00001"; -- => 2

   constant NC2_LS_LCLS2_C: slv(19 downto 0) := x"00001"; -- => 2
   constant NC2_LS_LCLS1_C: slv(19 downto 0) := x"00001"; -- => 2

   constant N2_HS_LCLS2_C:  slv( 2 downto 0) :=  "001";   -- => 5
   constant N2_HS_LCLS1_C:  slv( 2 downto 0) :=  "000";   -- => 4

   constant N2_LS_LCLS2_C:  slv(19 downto 0) := x"048D5"; -- => 18646
   constant N2_LS_LCLS1_C:  slv(19 downto 0) := x"038AF"; -- => 14512

   constant N31_LCLS2_C:    slv(18 downto 0) := "000" & x"0800"; -- => 2049
   constant N31_LCLS1_C:    slv(18 downto 0) := "000" & x"04F2"; -- => 1267

   constant N32_LCLS2_C:    slv(18 downto 0) := "000" & x"0800"; -- => 2049
   constant N32_LCLS1_C:    slv(18 downto 0) := "000" & x"04F2"; -- => 1267

   constant DELAY_C      : natural   := natural(AXIL_FREQ_G * 15.0E-3);
   constant TXRST_DELAY_C: natural   := 4;

   constant PRG_READ_TCA_C : AxiLiteProgramArray := (
       0 => tcaRd( true )
   );

   constant PRG_WRITE_TCA_C: AxiLiteProgramArray := (
       0 => tcaWr(     x"00", true  )
   ); 

   constant PRG_INIT_C     : AxiLiteProgramArray := (
      -- initialize I2C MUX/SWITCH and Si5328
       0 => clkWr(  0, x"54", false ), -- Free run
       1 => clkWr(  1, x"e5", false ), -- CLK2 first + 2nd priority
       2 => clkWr(  3, x"55", false ), -- manually select clk2
       3 => clkWr(  5, x"2d", false ), -- Icmos 8mA/5mA (value from system controller)
       4 => clkWr(  6, x"3f", false ), -- LVDS outputs  (value from system controller)
       5 => clkWr(  7, x"28", false ), -- FOS alarm ref. Xa/Xb
       6 => clkWr( 21, x"fc", false ), -- disable CS_CA (clock selection) pin
       7 => clkWr( 55, x"1c", true  )  -- Clkinrate (1300/7*2, value from system controller)
   );

   constant PRG_WRITE_LCLS_2_C    : AxiLiteProgramArray := (
      -- set new frequency
       0 => clkWr(  2, x"42", false ), -- BWsel    (dspllsim)
       1 => clkWr( 25, x"C0", false ), -- N1_HS    (dspllsim)
       2 => clkWr( 31, x"00", false ), -- NC1_LS   (dspllsim)
       3 => clkWr( 32, x"00", false ), -- NC1_LS   (dspllsim)
       4 => clkWr( 33, x"01", false ), -- NC1_LS   (dspllsim)
       5 => clkWr( 34, x"00", false ), -- NC2_LS   (dspllsim)
       6 => clkWr( 35, x"00", false ), -- NC2_LS   (dspllsim)
       7 => clkWr( 36, x"01", false ), -- NC2_LS   (dspllsim)
       8 => clkWr( 40, x"60", false ), -- N2_HS/LS (dspllsim)
       9 => clkWr( 41, x"59", false ), -- N2_LS    (dspllsim)
      10 => clkWr( 42, x"F9", false ), -- N2_LS    (dspllsim)
      11 => clkWr( 43, x"00", false ), -- N31      (dspllsim)
      12 => clkWr( 44, x"0E", false ), -- N31      (dspllsim)
      13 => clkWr( 45, x"A4", false ), -- N31      (dspllsim)
      14 => clkWr( 46, x"00", false ), -- N32      (dspllsim)
      15 => clkWr( 47, x"0E", false ), -- N32      (dspllsim)
      16 => clkWr( 48, x"A4", false ), -- N32      (dspllsim)
      17 => clkWr(136, x"40", true  )  -- ICAL
   );

   constant PRG_WRITE_LCLS_1_C    : AxiLiteProgramArray := (
       0 => clkWr(   2, x"62", false ), -- BWsel    (dspllsim)
       1 => clkWr(  25, x"e0", false ), -- N1_HS    (dspllsim)
       2 => clkWr(  31, x"00", false ), -- NC1_LS   (dspllsim)
       3 => clkWr(  32, x"00", false ), -- NC1_LS   (dspllsim)
       4 => clkWr(  33, x"01", false ), -- NC1_LS   (dspllsim)
       5 => clkWr(  34, x"00", false ), -- NC2_LS   (dspllsim)
       6 => clkWr(  35, x"00", false ), -- NC2_LS   (dspllsim)
       7 => clkWr(  36, x"01", false ), -- NC2_LS   (dspllsim)
       8 => clkWr(  40, x"00", false ), -- N2_HS/LS (dspllsim)
       9 => clkWr(  41, x"38", false ), -- N2_LS    (dspllsim)
      10 => clkWr(  42, x"af", false ), -- N2_LS    (dspllsim)
      11 => clkWr(  43, x"00", false ), -- N31      (dspllsim)
      12 => clkWr(  44, x"04", false ), -- N31      (dspllsim)
      13 => clkWr(  45, x"f2", false ), -- N31      (dspllsim)
      14 => clkWr(  46, x"00", false ), -- N32      (dspllsim)
      15 => clkWr(  47, x"04", false ), -- N32      (dspllsim)
      16 => clkWr(  48, x"f2", false ), -- N32      (dspllsim)
      17 => clkWr( 136, x"40", true  )  -- ICAL
   );

   constant PROGRAM_C    : AxiLiteProgramArray := (
     PRG_READ_TCA_C & PRG_WRITE_TCA_C & PRG_INIT_C & PRG_WRITE_LCLS_2_C & PRG_WRITE_LCLS_1_C
   );

   constant PC_READ_TCA_C     : natural := 0;
   constant PC_WRITE_TCA_C    : natural := PC_READ_TCA_C      + PRG_READ_TCA_C'length;
   constant PC_INIT_C         : natural := PC_WRITE_TCA_C     + PRG_WRITE_TCA_C'length;
   constant PC_WRITE_LCLS_2_C : natural := PC_INIT_C          + PRG_INIT_C'length;
   constant PC_WRITE_LCLS_1_C : natural := PC_WRITE_LCLS_2_C  + PRG_WRITE_LCLS_2_C'length;

   type StateType is (RESET, READ_TCA, WRITE_TCA, INIT, WRITE, DELY, IDLE);

   type RegType is record
      state      : StateType;
      nextState  : StateType;
      tcaVal     : slv( 7 downto 0);
      pc         : natural;
      nextPc     : natural;
      delay      : natural;
      trg        : sl;
      clkSel     : sl;
      txreset    : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state      => RESET,
      nextState  => IDLE,
      tcaVal     => (others => '0'),
      pc         => PC_READ_TCA_C,
      nextPc     =>  0,
      delay      =>  0,
      trg        => '0',
      clkSel     => '1',
      txreset    => '0'
   );

   constant NUM_RD_REGS_C : natural := 8;
   constant NUM_WR_REGS_C : natural := 1;

   constant WR_REG_CTRL_C : natural := 0;

   signal   seqProg       : AxiLiteProgramArray(PROGRAM_C'range) := PROGRAM_C;
 
   signal   r             : RegType := REG_INIT_C;
   signal   rin           : RegType;

   signal   rs, don       : sl;
   signal   rdData        : slv(31 downto 0);

   signal   rdRegs        : Slv32Array(NUM_RD_REGS_C - 1 downto 0) := (others => (others => '0') );
   signal   wrRegs        : Slv32Array(NUM_WR_REGS_C - 1 downto 0);

begin

   -- splice in run-time values
   seqProg( PC_WRITE_TCA_C ).req.wrData(7 downto 0)   <= r.tcaVal;

   P_COMB : process( clkSel, r, rs, don, rdData ) is
      variable v : RegType;
   begin
      v         := r;
      v.trg     := '0';

      case ( r.state ) is
         when RESET =>
            v.state     := READ_TCA;
            v.pc        := PC_READ_TCA_C;
            v.nextState := INIT;
            v.nextPc    := PC_INIT_C;
            v.trg       := '1';

         when READ_TCA  =>
            if ( rs = '1' ) then
               v.tcaVal := rdData(7 downto 0) or x"10"; -- open i2c route to Si5328
            end if;
            if ( don = '1' and r.trg = '0' ) then
               v.state := WRITE_TCA;
               v.pc    := PC_WRITE_TCA_C;
               v.trg   := '1';
            end if;

         when WRITE_TCA =>
            if ( don = '1' and r.trg = '0' ) then
               v.pc    := r.nextPc;
               v.state := r.nextState;
               v.trg   := '1';
            end if;

         when INIT =>
            if ( don = '1' and r.trg = '0' ) then
              if ( clkSel = '1' ) then
                v.pc := PC_WRITE_LCLS_2_C;
              else
                v.pc := PC_WRITE_LCLS_1_C;
              end if;
              v.clkSel := clkSel;
              v.trg    := '1';
              v.state  := WRITE;
            end if;
 
         when WRITE =>
            if ( don = '1' and r.trg = '0' ) then
              v.state := DELY;
              v.delay := DELAY_C;
            end if;

         when DELY =>
            if ( r.delay /= 0 ) then
               if ( r.delay < TXRST_DELAY_C ) then
                  v.txreset := '1';
               end if;
               v.delay := r.delay - 1;
            else
               v.state   := IDLE;
               v.txreset := '0';
            end if;

         when IDLE =>
            if ( clkSel /= r.clkSel ) then
               if ( clkSel = '1' ) then
                  v.nextPc := PC_WRITE_LCLS_2_C;
               else
                  v.nextPc := PC_WRITE_LCLS_1_C;
               end if;
               v.nextState  := WRITE;
               v.state      := READ_TCA;
               v.pc         := PC_READ_TCA_C;
               v.clkSel     := clkSel;
               v.trg        := '1';
            end if;

      end case;

      rin <= v;
   end process P_COMB;

   P_SEQ : process( axilClk ) is
   begin
      if ( rising_edge( axilClk ) ) then
         if ( axilRst = '1' ) then
            r <= REG_INIT_C;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process P_SEQ;

   U_SEQ : entity work.AxiLiteSequencer
      generic map (
         TPD_G           => TPD_G
      )
      port map (
         axilClk         => axilClk,
         axilRst         => axilRst,

         prog            => seqProg,
         trg             => r.trg,
         pc              => r.pc,
         rs              => rs,
         don             => don,
         rdData          => rdData,

         axilReadMaster  => mAxilReadMaster,
         axilReadSlave   => mAxilReadSlave,
         axilWriteMaster => mAxilWriteMaster,
         axilWriteSlave  => mAxilWriteSlave
      );

   U_SLV : entity work.AxiLiteRegs
      generic map (
         TPD_G           => TPD_G,
         NUM_WRITE_REG_G => NUM_WR_REGS_C,
         NUM_READ_REG_G  => NUM_RD_REGS_C
      )
      port map (
         axiClk          => axilClk,
         axiClkRst       => axilRst,
         axiReadMaster   => sAxilReadMaster,
         axiReadSlave    => sAxilReadSlave,
         axiWriteMaster  => sAxilWriteMaster,
         axiWriteSlave   => sAxilWriteSlave,
         writeRegister   => wrRegs,
         readRegister    => rdRegs
      );

   txRst   <= r.txreset or wrRegs(WR_REG_CTRL_C)(1);
   rxRst   <= r.txreset;

end architecture TimingClkSwitcherSi5328;
