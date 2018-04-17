library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiLiteMasterPkg.all;
use work.AxiLiteSequencerPkg.all;

entity AxiLiteSequencerTb is
end entity AxiLiteSequencerTb;

architecture impl of AxiLiteSequencerTb is

   constant NR_C : natural := 4;

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal run : boolean := true;

   signal axilReadMaster   : AxiLiteReadMasterType;
   signal axilReadSlave    : AxiLiteReadSlaveType;
   signal axilWriteMaster  : AxiLiteWriteMasterType;
   signal axilWriteSlave   : AxiLiteWriteSlaveType;

   signal wrRegs           : Slv32Array(NR_C - 1 downto 0);
   signal rdRegs           : Slv32Array(NR_C - 1 downto 0) := (
      0 => x"babe_cabe",
      1 => x"1234_5678",
      2 => x"0000_0000",
      3 => x"8765_4321"
   );

   signal don              : sl;
   signal trg              : sl := '0';
   signal pc               : natural := 0;
   signal rdData           : slv(31 downto 0);

   signal cnt              : natural := 0;

   constant PROG_C         : AxiLiteProgramArray := (
      0 => axiLiteWriteInst(x"0000_0100", x"0000_0000", false),
      1 => axiLiteWriteInst(x"0000_0104", x"1111_1111", true ),
      2 => axiLiteWriteInst(x"0000_0108", x"2222_2222", true ),
      3 => axiLiteWriteInst(x"0000_010c", x"3333_3333", true ),
      4 => axiLiteWriteInst(x"0000_010c", x"ffff_ffff", false),
      5 => axiLiteWriteInst(x"0000_0108", x"eeee_eeee", false),
      6 => axiLiteWriteInst(x"0000_0104", x"dddd_dddd", false),
      7 => axiLiteWriteInst(x"0000_0100", x"cccc_cccc", true ),
      8 => axiLiteReadInst (x"0000_000c",               true ),
      9 => axiLiteReadInst (x"0000_0008",               true ),
     10 => axiLiteReadInst (x"0000_0004",               true ),
     11 => axiLiteReadInst (x"0000_0000",               true )
   );

   impure function verifyWr(pc : in natural) return boolean is
   begin
      return PROG_C(pc).req.wrData = wrRegs( to_integer( unsigned( PROG_C(pc).req.address(7 downto 2) ) ) );
   end function verifyWr;

   impure function verifyRd(pc : in natural) return boolean is
   begin
      return rdData = rdRegs( to_integer( unsigned( PROG_C(pc).req.address(7 downto 2) ) ) );
   end function verifyRd;

   impure function checkWrRange(pc : in natural) return boolean is
      variable i : natural;
   begin
      i := pc;
      while ( not PROG_C(i).lst ) loop
         if (not verifyWr( i )) then
            return false;
         end if;
         i := i + 1;
      end loop;
      return verifyWr( i );
   end function;

begin

   P_CLK : process is
   begin
      if ( run ) then
         clk <= not clk;
         wait for 10 ns;
      else
         wait;
      end if;
   end process P_CLK;

   P_SEQ : process( clk ) is
   variable v : natural;
   begin
   if ( rising_edge(clk) ) then
      v := cnt + 1;

      case (cnt) is
         when 3 =>
            rst <= '0';

         when 5 =>
            trg <= '1';
            pc  <=  0;

         when 7 =>
            trg <= '0';
            if ( don /= '1' ) then
               v := cnt;
            else
               assert checkWrRange( 0 ) severity failure;
            end if;

         when 8 =>
            trg <= '1';
            pc  <=  2;

         when 10 => -- one cycle to deassert 'don'
            trg <= '0';
            if ( don /= '1' ) then
               v := cnt;
            else
               assert checkWrRange( 2 ) severity failure;
            end if;

         when 11 =>
            trg <= '1';
            pc  <=  3;

         when 13 => -- one cycle to deassert 'don'
            trg <= '0';
            if ( don /= '1' ) then
               v := cnt;
            else
               assert checkWrRange( 3 ) severity failure;
            end if;

         when 14 =>
            trg <= '1';
            pc  <=  4;

         when 16 => -- one cycle to deassert 'don'
            trg <= '0';
            if ( don /= '1' ) then
               v := cnt;
            else
               assert checkWrRange( 4 ) severity failure;
            end if;

         when 20 | 24 | 28 | 32 =>
            trg <= '1';
            pc  <= (cnt - 20)/4 + 8;

         when 22 | 26 | 30 | 34 =>
            trg <= '0';
            if ( don /= '1' ) then
               v := cnt;
            else
               assert verifyRd( pc ) severity failure;
            end if;

         when 99 =>
            report "TEST PASSED";
            run <= false;

         when others =>
      end case;

      cnt <= v;
   end if;
   end process P_SEQ;

   U_DUT : entity work.AxiLiteSequencer
      port map (
         axilClk         => clk,
         axilRst         => rst,

         prog            => PROG_C,

         trg             => trg,
         don             => don,
         pc              => pc,
         rdData          => rdData,

         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave
      );

   U_SLV : entity work.AxiLiteEmpty
      generic map (
         NUM_WRITE_REG_G => 4,
         NUM_READ_REG_G  => 4
      )
      port map (
         axiClk          => clk,
         axiClkRst       => rst,

         axiWriteMaster  => axilWriteMaster,
         axiWriteSlave   => axilWriteSlave,
         axiReadMaster   => axilReadMaster,
         axiReadSlave    => axilReadSlave,
         writeRegister   => wrRegs,
         readRegister    => rdRegs
      );

end architecture impl;

