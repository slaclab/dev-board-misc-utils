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
