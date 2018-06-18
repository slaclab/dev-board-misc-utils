-------------------------------------------------------------------------------
-- File       : AxiLiteSequencerPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Sequence multiple Axi-Lite transactions
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
use work.AxiLitePkg.all;
use work.AxiLiteMasterPkg.all;

package AxiLiteSequencerPkg is

   type AxiLiteInstructionType is record
      req : AxiLiteMasterReqType;
      lst : boolean;
   end record AxiLiteInstructionType;

   constant AXI_LITE_INSTRUCTION_INIT_C : AxiLiteInstructionType := (
      req => AXI_LITE_MASTER_REQ_INIT_C,
      lst => true
   );

   function axiLiteWriteInst(
      addr : in slv(31 downto 0);
      data : in slv(31 downto 0);
      last : in boolean := true
   ) return AxiLiteInstructionType;

   function axiLiteReadInst(
      addr : in slv(31 downto 0);
      last : in boolean := true
   ) return AxiLiteInstructionType;

   type AxiLiteProgramArray is array (natural range <>) of AxiLiteInstructionType;

end package AxiLiteSequencerPkg;

package body AxiLiteSequencerPkg is

   function axiLiteWriteInst(
      addr : in slv(31 downto 0);
      data : in slv(31 downto 0);
      last : in boolean := true
   ) return AxiLiteInstructionType is
      variable v : AxiLiteInstructionType;
   begin
      v := AXI_LITE_INSTRUCTION_INIT_C;

      v.req.rnw     := '0';
      v.req.address := addr;
      v.req.wrData  := data;
      v.lst         := last;

      return v;
   end function axiLiteWriteInst;

   function axiLiteReadInst(
      addr : in slv(31 downto 0);
      last : in boolean := true
   ) return AxiLiteInstructionType is
      variable v : AxiLiteInstructionType;
   begin
      v := AXI_LITE_INSTRUCTION_INIT_C;

      v.req.rnw     := '1';
      v.req.address := addr;
      v.lst         := last;
      return v;
   end function axiLiteReadInst;

end package body AxiLiteSequencerPkg;
