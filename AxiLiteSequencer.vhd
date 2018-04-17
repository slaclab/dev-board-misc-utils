-------------------------------------------------------------------------------
-- File       : AxiLiteSequencer.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-03-08
-- Last update: 2016-03-09
-------------------------------------------------------------------------------
-- Description: Sequence multiple Axi-Lite transactions
-------------------------------------------------------------------------------
-- This file is part of SLAC Firmware Standard Library. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SLAC Firmware Standard Library, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiLiteMasterPkg.all;
use work.AxiLiteSequencerPkg.all;

entity AxiLiteSequencer is
   generic (
      TPD_G            : time         := 1 ns
   );
   port (
      axilClk          : in  sl;
      axilRst          : in  sl;

      prog             : in  AxiLiteProgramArray;

      trg              : in  sl;
      pc               : in  natural;
      rs               : out sl;
      don              : out sl;
      rdData           : out slv(31 downto 0);

      axilReadMaster   : out AxiLiteReadMasterType;
      axilReadSlave    : in  AxiLiteReadSlaveType  := AXI_LITE_READ_SLAVE_INIT_C;
      axilWriteMaster  : out AxiLiteWriteMasterType;
      axilWriteSlave   : in  AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_INIT_C
   );
end entity AxiLiteSequencer;

architecture AxiLiteSequencerImpl of AxiLiteSequencer is

   type StateType is (IDLE, REQ, WAI);

   type RegType is record
      pc      : natural;
      inst    : AxiLiteInstructionType;
      don     : sl;
      state   : StateType;
      data    : slv(31 downto 0); -- readback data
      rs      : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      pc     => 0,
      inst   => AXI_LITE_INSTRUCTION_INIT_C,
      don    => '0',
      state  => IDLE,
      data   => x"0000_0000",
      rs     => '0'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   signal ack : AxiLiteMasterAckType;

begin

   P_COMB : process(r, ack, trg, pc, prog) is
      variable v : RegType;
   begin
      v    := r;
      v.rs := '0';

      case ( r.state ) is
         when IDLE =>
            if ( trg = '1' ) then
               v.pc    := pc;
               v.state := REQ;
               v.don   := '0';
            end if;

         when REQ  =>
            v.inst             := prog(r.pc);
            v.inst.req.request := '1';
            v.state            := WAI;
            v.pc               := r.pc + 1;

         when WAI  =>
            if ( ack.done = '1' ) then
               v.inst.req.request := '0';
               if ( r.inst.req.rnw = '1' ) then
                  v.data := ack.rdData;
                  v.rs   := '1';
               end if;
               if ( r.inst.lst ) then
                  v.don   := '1';
                  v.state := IDLE;
               else
                  v.state := REQ;
               end if;
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

   U_MASTER : entity work.AxiLiteMaster
      generic map (
         TPD_G           => TPD_G
      )
      port map (
         axilClk         => axilClk,
         axilRst         => axilRst,
         req             => r.inst.req,
         ack             => ack,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave
      );

   rs     <= r.rs;
   don    <= r.don;
   rdData <= r.data;

end architecture AxiLiteSequencerImpl;
