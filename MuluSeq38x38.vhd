library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- multiply two unsigned 38-bit words keeping
-- the upper 38 bits of the result and add an offset:
--
--   p = ((a*b)>>38) + c
--
--  - synchronous reset
--  - latch input operands and start computation on 'trg'
--  - assert 'don' when output is valid
--

entity MuluSeq38x38 is
   generic (
      TPD_G           : time    := 1 ns
   );
   port (
      clk    : in  std_logic;
      rst    : in  std_logic;
      trg    : in  std_logic;
      a      : in  unsigned(37 downto 0);
      b      : in  unsigned(37 downto 0);
      c      : in  unsigned(37 downto 0) := (others => '0');
      p      : out unsigned(37 downto 0);
      don    : out std_logic
   );
end entity MuluSeq38x38;
