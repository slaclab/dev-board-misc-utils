-------------------------------------------------------------------------------
-- File       : MuluSeq38x38SeqImpl.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Sequential implementation of unsigned 38x38 bit multiplier
-------------------------------------------------------------------------------
-- This file is part of 'Development Board Misc. Utilities Library'
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'Development Board Misc. Utilities Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

architecture SeqImpl of MuluSeq38x38 is

   constant WIDTH_C : positive := 38;

begin

   U_Mul : entity work.MuluSeq
      generic map (
         TPD_G    => TPD_G,
         WIDTH_G  => WIDTH_C
      )
      port map (
         clk      => clk,
         rst      => rst,
         trg      => trg,
         a        => a,
         b        => b,
         d        => c,
         p        => p,
         don      => don
      );

end architecture SeqImpl;
