library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MuluSeq21x17Dsp is
   generic (
      TPD_G           : time    := 1 ns;
      RESET_PM_ONLY_G : boolean := false
   );
   port (
      clk    : in  std_logic;
      rst    : in  std_logic;
      s17    : in  std_logic;
      a      : in  unsigned(20 downto 0);
      b      : in  unsigned(16 downto 0);
      p      : out unsigned(46 downto 0)
   );
end entity MuluSeq21x17Dsp;

architecture Impl of MuluSeq21x17Dsp is
   type RegType is record
      a  : signed(21 downto 0);
      b  : signed(17 downto 0);
      m  : signed(39 downto 0);
      p  : signed(47 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      a   => (others => '0'),
      b   => (others => '0'),
      m   => (others => '0'),
      p   => (others => '0')
   );

   signal r : RegType := REG_INIT_C;

   signal rin : RegType;

begin

   P_CMB : process ( a, b, s17, r ) is
      variable v: RegType;
   begin
      v     := r;
      v.a   := signed( resize(a, v.a'length) );
      v.b   := signed( resize(b, v.b'length) );
      v.m   := r.a*r.b;

      if ( s17 = '1' ) then
         v.p := shift_right(r.p, 17) + r.m;
      else
         v.p := r.p + r.m;
      end if;

      rin <= v;
   end process P_CMB;

   P_SEQ : process ( clk ) is
      variable v : RegType;
   begin
      if ( rising_edge( clk ) ) then
         v := rin;
         if ( rst = '1' ) then
            if ( RESET_PM_ONLY_G ) then
               v.m := (others => '0');
               v.p := (others => '0');
            else
               v   := REG_INIT_C;
            end if;
         end if;
         r <= v after TPD_G;
      end if;
   end process P_SEQ;

   p <= unsigned( resize(r.p, p'length) );

end architecture Impl;
