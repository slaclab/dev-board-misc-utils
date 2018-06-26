-------------------------------------------------------------------------------
-- File       : TimingClkSwitcher.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Switch Timing GTH Si570 Reference Clock
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
--   1) resets the SI570 to factory settings (during initialization)
--   2) reads back and stores the factory trimmed parameters (which yield 156.25MHz)
--   3) monitors clkSel and switches the SI570 to generate
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
use work.AxiLiteMasterPkg.all;
use work.AxiLiteSequencerPkg.all;

architecture TimingClkSwitcherSi570 of TimingClkSwitcher is

   function regOff(b : slv; o : natural) return slv is
      variable r : unsigned(b'range);
   begin
      r := unsigned(b) + shift_left(to_unsigned(o, 32),2);
      return slv(r);
   end function regOff;

   subtype RfReqType is unsigned(37 downto 0);

   -- factory output frequency of Kcu105's Si570 is 156.25Mhz.
   -- HS_DIV = 4, N1 = 8 -> nominal VCO freq. is 5000MHz

   -- LCLS2 ref. frequency is twice timing clock = 2*1300/7 
   -- with HS_DIV=7, N1 = 2 -> VCO freq  = 5200MHz

   -- LCLS1 ref. frequency is twice timing clock = 2*119
   -- with HS_DIV=11, N1 = 2 -> VCO freq = 5236MHz

   constant HS_DIV_LCLS2_C : slv(2 downto 0) := "011";     -- => 7
   constant N1_LCLS2_C   : slv(6 downto 0) := "0000001"; -- => 2

   -- refreq = 5200/5000*refreqRef = refreqRef + 200/5000*refreqRef = refreqRef + DEL_LCLS2
   constant DEL_LCLS2_C  : RfReqType := resize( x"2_8F5C_28F6", RfReqType'length );

   constant HS_DIV_LCLS1_C : slv(2 downto 0) := "111";     -- => 11
   constant N1_LCLS1_C   : slv(6 downto 0) := "0000001"; -- => 2

   -- refreq = 5236/5000*refreqRef = refreqRef + 236/5000*refreqRef = refreqRef + DEL_LCLS1
   constant DEL_LCLS1_C  : RfReqType := resize( x"3_0553_2618", RfReqType'length );

   constant DELAY_C      : natural   := natural(AXIL_FREQ_G * 15.0E-3);
   constant TXRST_DELAY_C: natural   := 4;

   constant SI570_R7     : slv(31 downto 0) := regOff(CLOCK_AXIL_BASE_ADDR_G,  7);
   constant SI570_R8     : slv(31 downto 0) := regOff(CLOCK_AXIL_BASE_ADDR_G,  8);
   constant SI570_R9     : slv(31 downto 0) := regOff(CLOCK_AXIL_BASE_ADDR_G,  9);
   constant SI570_RA     : slv(31 downto 0) := regOff(CLOCK_AXIL_BASE_ADDR_G, 10);
   constant SI570_RB     : slv(31 downto 0) := regOff(CLOCK_AXIL_BASE_ADDR_G, 11);
   constant SI570_RC     : slv(31 downto 0) := regOff(CLOCK_AXIL_BASE_ADDR_G, 12);
   constant SI570_R135   : slv(31 downto 0) := regOff(CLOCK_AXIL_BASE_ADDR_G,135);
   constant SI570_R137   : slv(31 downto 0) := regOff(CLOCK_AXIL_BASE_ADDR_G,137);

   constant PRG_READ_TCA_C : AxiLiteProgramArray := (
      0 => axiLiteReadInst ( TCASW_AXIL_BASE_ADDR_G,               true  )
   );

   constant PRG_INIT_C     : AxiLiteProgramArray := (
      -- initialize I2C MUX/SWITCH and Si570
      0 => axiLiteWriteInst( TCASW_AXIL_BASE_ADDR_G, x"0000_0000", false ),
      1 => axiLiteWriteInst( SI570_R135            , x"0000_0001", false ),
      2 => axiLiteReadInst ( SI570_R135            ,               true  )
   );

   constant PRG_RDBK_C     : AxiLiteProgramArray := (
      -- calibrated refreq register readback
      0 => axiLiteReadInst ( SI570_R8              ,               false ),
      1 => axiLiteReadInst ( SI570_R9              ,               false ),
      2 => axiLiteReadInst ( SI570_RA              ,               false ),
      3 => axiLiteReadInst ( SI570_RB              ,               false ),
      4 => axiLiteReadInst ( SI570_RC              ,               true  )
   );

   constant PRG_WRITE_C    : AxiLiteProgramArray := (
      -- set new frequency
      0 => axiLiteWriteInst( SI570_R137            , x"0000_0010", false ), -- freeze
      1 => axiLiteWriteInst( SI570_R7              , x"0000_0000", false ),
      2 => axiLiteWriteInst( SI570_R8              , x"0000_0000", false ),
      3 => axiLiteWriteInst( SI570_R9              , x"0000_0000", false ),
      4 => axiLiteWriteInst( SI570_RA              , x"0000_0000", false ),
      5 => axiLiteWriteInst( SI570_RB              , x"0000_0000", false ),
      6 => axiLiteWriteInst( SI570_RC              , x"0000_0000", false ),
      7 => axiLiteWriteInst( SI570_R137            , x"0000_0000", false ), -- unfreeze
      8 => axiLiteWriteInst( SI570_R135            , x"0000_0040", true  )  -- new Freq
   );

   constant PC_READ_TCA_C   : natural := 0;
   constant PC_INIT_C       : natural := PC_READ_TCA_C  + PRG_READ_TCA_C'length;
   constant PC_POLL_SI_C    : natural := PC_INIT_C      + 2;
   constant PC_RDBK_C       : natural := PC_INIT_C      + PRG_INIT_C'length;
   constant PC_WRITE_C      : natural := PC_RDBK_C      + PRG_RDBK_C'length;

   constant PC_SETFREQ_C    : natural := PC_WRITE_C     + 7;

   constant PROGRAM_C    : AxiLiteProgramArray := (
     PRG_READ_TCA_C & PRG_INIT_C & PRG_RDBK_C & PRG_WRITE_C
   );

   type StateType is (RESET, READ_TCA, POLL_SI, INIT_LCLS2, INIT_LCLS1, DELY, RDBK, SET_LCLS2, SET_LCLS1, WRITE, IDLE, SETFREQ);

   type RegType is record
      state      : StateType;
      prevState  : StateType;
      tcaVal     : slv( 7 downto 0);
      r7to12     : slv(47 downto 0);
      rfreqRef   : RfReqType;
      rfreqLcls2 : RfReqType;
      rfreqLcls1 : RfReqType;
      pc         : natural;
      delay      : natural;
      trg        : sl;
      mulTrg     : sl;
      clkSel     : sl;
      txreset    : sl;
      newFreq    : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state      => RESET,
      prevState  => IDLE,
      tcaVal     => (others => '0'),
      r7to12     => (others => '0'),
      rfreqRef   => (others => '0'),
      rfreqLcls2 => (others => '0'),
      rfreqLcls1 => (others => '0'),
      pc         => PC_READ_TCA_C,
      delay      =>  0,
      trg        => '0',
      mulTrg     => '0',
      clkSel     => '1',
      txreset    => '0',
      newFreq    => '0'
   );

   constant NUM_RD_REGS_C : natural := 8;
   constant NUM_WR_REGS_C : natural := 1;

   constant WR_REG_CTRL_C : natural := 0;

   constant RD_REG_REF_C  : natural := 0;
   constant RD_REG_LCLS1_C: natural := 2;
   constant RD_REG_LCLS2_C: natural := 4;

   signal   seqProg       : AxiLiteProgramArray(PROGRAM_C'range) := PROGRAM_C;
 
   signal   r             : RegType := REG_INIT_C;
   signal   rin           : RegType;

   signal   rs, don       : sl;
   signal   rdData        : slv(31 downto 0);

   signal   bMux          : RfReqType;

   signal   p             : RfReqType;
   signal   mulDon        : sl;
   signal   newFreq       : sl;

   signal   rdRegs        : Slv32Array(NUM_RD_REGS_C - 1 downto 0) := (others => (others => '0') );
   signal   wrRegs        : Slv32Array(NUM_WR_REGS_C - 1 downto 0);
begin
   -- splice in run-time values
   seqProg( PC_INIT_C ).req.wrData(7 downto 0)   <= r.tcaVal;

   GEN_SPLICE : for i in 0 to 5 generate
      seqProg(PC_WRITE_C + 1 + i).req.wrData(7 downto 0) <= r.r7to12((5-i)*8+7 downto (5-i)*8);
   end generate;

   P_COMB : process( clkSel, r, rs, don, rdData, p, mulDon, newFreq ) is
      variable v : RegType;
   begin
      v         := r;
      v.trg     := '0';
      v.mulTrg  := '0';
      v.newFreq := newFreq;

      case ( r.state ) is
         when RESET =>
            v.state := READ_TCA;
            v.pc    := PC_READ_TCA_C;
            v.trg   := '1';

         when READ_TCA  =>
            if ( rs = '1' ) then
               v.tcaVal := rdData(7 downto 0) or x"01"; -- open i2c route to Si570
            end if;
            if ( don = '1' ) then
               v.state := POLL_SI;
               v.pc    := PC_INIT_C;
               v.trg   := '1';
            end if;
 
         when POLL_SI =>
            if ( rs = '1' and don = '1' ) then
               if ( rdData(0) = '0' ) then
                  v.state := RDBK;
                  v.pc    := PC_RDBK_C;
               else
                  v.pc    := PC_POLL_SI_C;
               end if;
               v.trg   := '1';
            end if;

         when RDBK =>
            if ( rs = '1' ) then
               v.rfreqRef := r.rfreqRef(29 downto 0) & unsigned(rdData(7 downto 0));
               if ( don = '1' ) then
                  v.state  := INIT_LCLS2;
                  v.mulTrg := '1';
               end if;
            end if;

         when INIT_LCLS2 =>
            if ( mulDon = '1' and r.mulTrg = '0' ) then
               v.state      := INIT_LCLS1;
               v.mulTrg     := '1';
               v.rfreqLcls2 := p;
            end if;

         when INIT_LCLS1 =>
            if ( mulDon = '1' and r.mulTrg = '0' ) then
               v.state      := INIT_LCLS1;
               v.rfreqLcls1 := p;
               if (clkSel = '1') then
                  v.state := SET_LCLS2;
               else
                  v.state := SET_LCLS1;
               end if;
               v.clkSel := clkSel;
            end if;

         when SET_LCLS2 =>
            v.r7to12 := HS_DIV_LCLS2_C & N1_LCLS2_C & slv(r.rfreqLcls2);
            v.state  := WRITE;
            v.pc     := PC_WRITE_C;
            v.trg    := '1';

         when SET_LCLS1 =>
            v.r7to12 := HS_DIV_LCLS1_C & N1_LCLS1_C & slv(r.rfreqLcls1);
            v.state  := WRITE;
            v.pc     := PC_WRITE_C;
            v.trg    := '1';

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
                  v.state := SET_LCLS2;
               else
                  v.state := SET_LCLS1;
               end if;
               v.clkSel := clkSel;
            elsif ( newFreq /= '0' and r.newFreq = '0' ) then
               v.state  := SETFREQ;
               v.pc     := PC_SETFREQ_C;
               v.trg    := '1';
            end if;

         when SETFREQ =>
            if ( don = '1' ) then
               v.state := IDLE;
            end if;
            
      end case;

      rin <= v;
   end process P_COMB;

   P_MUX : process(r) is
   begin
      if ( r.state /= INIT_LCLS2 ) then
         bMux <= DEL_LCLS1_C;
      else
         bMux <= DEL_LCLS2_C;
      end if;
   end process P_MUX;

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

   U_MUL : entity work.MuluSeq38x38(SeqImpl)
      generic map (
         TPD_G   => TPD_G
      )
      port map (
         clk     => axilClk,
         rst     => axilRst,
         trg     => r.mulTrg,
         a       => r.rfreqRef,
         b       => bMux,
         c       => r.rfreqRef,
         p       => p,
         don     => mulDon
      );

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

   rdRegs(RD_REG_REF_C   +  0)             <= slv(r.rfreqRef(31 downto 0));
   rdRegs(RD_REG_REF_C   +  1)(5 downto 0) <= slv(r.rfreqRef(37 downto 32));
   rdRegs(RD_REG_LCLS1_C +  0)             <= slv(r.rfreqLcls1(31 downto 0));
   rdRegs(RD_REG_LCLS1_C +  1)(5 downto 0) <= slv(r.rfreqLcls1(37 downto 32));
   rdRegs(RD_REG_LCLS2_C +  0)             <= slv(r.rfreqLcls2(31 downto 0));
   rdRegs(RD_REG_LCLS2_C +  1)(5 downto 0) <= slv(r.rfreqLcls2(37 downto 32));

   newFreq <= wrRegs(WR_REG_CTRL_C)(0);
   txRst   <= r.txreset or wrRegs(WR_REG_CTRL_C)(1);
   rxRst   <= r.txreset;

end architecture TimingClkSwitcherSi570;
