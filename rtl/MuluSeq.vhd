-------------------------------------------------------------------------------
-- File       : MuluSeq.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Entity declaration of unsigned N x N bit multiplier.
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

-- multiply two unsigned N-bit words keeping
-- the upper N bits of the result and add an offset:
--
--   p = ((a*b)>>N) + c
--
--  - synchronous reset
--  - latch input operands and start computation on 'trg'
--  - assert 'don' when output is valid
--

entity MuluSeq is
   generic (
      TPD_G           : time    := 1 ns;
      WIDTH_G         : positive
   );
   port (
      clk    : in  std_logic;
      rst    : in  std_logic;
      trg    : in  std_logic;
      a      : in  unsigned(WIDTH_G - 1 downto 0);
      b      : in  unsigned(WIDTH_G - 1 downto 0);
      c      : in  unsigned(WIDTH_G - 1 downto 0) := (others => '0');
      p      : out unsigned(WIDTH_G - 1 downto 0);
      don    : out std_logic
   );
end entity MuluSeq;

architecture Impl of MuluSeq is

   subtype CountType is natural range 0 to WIDTH_G - 1;

   type    StateType is (IDLE, MUL, ADD);

   type RegType is record
      a   : unsigned(WIDTH_G - 1 downto 0);
      b   : unsigned(WIDTH_G - 1 downto 0);
      c   : unsigned(WIDTH_G - 1 downto 0);
      p   : unsigned(WIDTH_G - 1 downto 0);
      cnt : CountType;
      sta : StateType;
      don : std_logic;
   end record;

   constant REG_INIT_C : RegType := (
      a   => (others => '0'),
      b   => (others => '0'),
      c   => (others => '0'),
      p   => (others => '0'),
      cnt => 0,
      sta => IDLE,
      don => '0'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   P_COMB : process(r, a, b, c, trg) is
      variable v : RegType;
      variable s : unsigned(WIDTH_G downto 0);
   begin

      v := r;

      case ( r.sta ) is

         when IDLE =>
            if ( trg = '1' ) then
               v.a   := a;
               v.b   := b;
               v.c   := c;
               v.p   := to_unsigned(0, v.p'length);
               v.cnt := 0;
               v.sta := MUL;
               v.don := '0';
            end if;

         when MUL  =>
            s := '0' & r.p;
            if ( r.a(r.cnt) = '1' ) then
              s   := s + ('0' & r.b);
            end if;
            s   := s srl 1;
            v.p := s(WIDTH_G - 1 downto 0);
   
            if ( r.cnt = WIDTH_G - 1 ) then
              v.sta := ADD;
            else
              v.cnt := r.cnt + 1;
            end if;

         when ADD  =>
            v.p   := r.p + c;
            v.sta := IDLE;
            v.don := '1';

      end case;

      rin <= v;

   end process P_COMB;

   P_SEQ : process (clk) is
   begin
      if ( rising_edge( clk ) ) then
         if ( rst = '1' ) then
            r <= REG_INIT_C;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process P_SEQ;

   p   <= r.p;
   don <= r.don;

end architecture Impl;
