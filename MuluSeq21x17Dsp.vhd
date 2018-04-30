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

architecture Inferred of MuluSeq21x17Dsp is
   type RegType is record
      a  : signed(21 downto 0);
      b  : signed(17 downto 0);
      m  : signed(39 downto 0);
      c  : signed(47 downto 0);
      p  : signed(47 downto 0);
      s17: std_logic;
      z  : std_logic;
   end record RegType;

   constant REG_INIT_C : RegType := (
      a   => (others => '0'),
      b   => (others => '0'),
      m   => (others => '0'),
      c   => (others => '0'),
      p   => (others => '0'),
      s17 => '0',
      z   => '0'
   );

   signal r : RegType := REG_INIT_C;

   signal rin : RegType;

begin

   P_CMB : process ( a, b, c, z, cec, s17, r ) is
      variable v: RegType;
   begin
      v     := r;
      v.a   := signed( resize(a, v.a'length) );
      v.b   := signed( resize(b, v.b'length) );
      v.m   := r.a*r.b;
      v.s17 := s17;
      v.z   := z;

      if ( cec = '1' ) then
        v.c := signed( resize(c, v.c'length) );
      end if;

      if ( r.z = '1' ) then
         v.p := r.p + r.c;
      else
         if ( r.s17 = '1' ) then
            v.p := shift_right(r.p, 17) + r.m;
         else
            v.p := r.p + r.m;
         end if;
      end if;

      rin <= v;
   end process P_CMB;

   P_SEQ : process ( clk ) is
      variable v : RegType;
   begin
      if ( rising_edge( clk ) ) then
         v := rin;
         if ( rst = '1' ) then
            v   := REG_INIT_C;
         elsif ( rstpm = '1' ) then
            v.m := (others => '0');
            v.p := (others => '0');
         end if;
         r <= v after TPD_G;
      end if;
   end process P_SEQ;

   p <= unsigned( resize(r.p, p'length) );

end architecture Inferred;
