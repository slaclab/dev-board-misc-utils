-------------------------------------------------------------------------------
-- File       : MuluSeq21x17Dsp.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Entity declaration of MuluSeq21x17Dsp (21x17 bit unsigned multiplier)
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

entity MuluSeq21x17Dsp is
   generic (
      TPD_G           : time    := 1 ns
   );
   port (
      clk    : in  std_logic;
      rst    : in  std_logic;
      rstpm  : in  std_logic;
      s17    : in  std_logic;
      z      : in  std_logic             := '0';
      a      : in  unsigned(20 downto 0);
      b      : in  unsigned(16 downto 0);
      cec    : in  std_logic             := '0';
      c      : in  unsigned(46 downto 0) := (others => '0');
      p      : out unsigned(46 downto 0)
   );
end entity MuluSeq21x17Dsp;
