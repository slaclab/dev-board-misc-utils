library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- multiply two unsigned 38-bit words with some
-- truncation:
--
-- With Ah : a(37 downto 17)  [21-bits]
--      Al : a(16 downto  0)  [17-bits]
--
--      Bh : b(37 downto 21)  [17-bits]
--      Bm : b(20 downto  4)  [17-bits]
--      Bl : b( 3 downto  0)  [ 4-bits]
--
--      P =                  Al*Bl <<  0  (21 bits)   x)
--        +                  Al*Bm <<  4  (38 bits)   y)
--        +                  Al*Bh << 21  (55 bits)
--        +                  Ah*Bl << 17  (42 bits)
--        +                  Ah*Bm << 21  (59 bits)
--        +                  Ah*Bh << 38  (76 bits)
--
-- Neglecting x,y which introduces an error less than (2<<38)
-- the upper 38 bits of the product become:
--
--   Ah*Bh + (Ah*Bm + Al*Bh) >> 17 + (Ah*Bl) >> 21
-- 
-- = Ah*Bh + (Ah*Bm + Al*Bh + (Ah*(Bl<<13)) >> 17) >> 17
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

architecture Impl of MuluSeq38x38 is
   type StateType is (TRIG, AHBL, AHBM, ALBH, AHBH, CADD, DONE);

   type RegType is record
      state : StateType;
      ah    : unsigned(20 downto 0);
      al    : unsigned(16 downto 0);
      bh    : unsigned(16 downto 0);
      bm    : unsigned(16 downto 0);
      s17   : std_logic;
      z     : std_logic;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state => DONE,
      ah    =>  (others => '0'),
      al    =>  (others => '0'),
      bh    =>  (others => '0'),
      bm    =>  (others => '0'),
      s17   =>  '0',
      z     =>  '0'
   );

   signal r    : RegType := REG_INIT_C;

   signal rin  : RegType;

   signal muxA : unsigned(20 downto 0);
   signal muxB : unsigned(16 downto 0);

   signal ah   : unsigned(20 downto 0);
   signal al   : unsigned(16 downto 0);
   signal bh   : unsigned(16 downto 0);
   signal bm   : unsigned(16 downto 0);
   signal bl   : unsigned( 3 downto 0);

   signal pLoc : unsigned(46 downto 0);

begin

   ah <= resize(
            shift_right( a, al'length ),
            ah'length
         );
   al <= resize(
            a,
            al'length
         );

   bh <= resize(
            shift_right( b, bm'length + bl'length ),
            bh'length
         );
   bm <= resize(
            shift_right(b, bl'length),
            bm'length
         );
   bl <= resize(
            b,
            bl'length
         );

   P_MUX : process ( trg, r ) is
      variable vA : unsigned(20 downto 0);
      variable vB : unsigned(16 downto 0);
   begin
      vA := (others => '0');
      vB := (others => '0');
      if ( trg = '1' ) then
         vA := ah;
         vB := shift_left(resize(bl, vB'length), 13); 
      else
         case ( r.state ) is
            when TRIG =>
              vA := ah;
              vB := bm;
            when AHBL =>
              vA := resize(al, vA'length);
              vB := bh;
            when AHBM =>
              vA := ah;
              vB := bh;
            when others =>
         end case;
      end if;

      muxA <= vA;
      muxB <= vB;
   end process P_MUX;

   P_CMB : process ( a, b, trg, r ) is
      variable v: RegType;
   begin
      v   := r;

      if ( trg = '1' ) then
         v.ah    := ah;
         v.al    := al;
         v.bh    := bh;
         v.bm    := bm;
         v.s17   := '0';
         v.z     := '0';
         v.state := TRIG;
      else
         case ( r.state ) is
            when TRIG =>
               v.state := AHBL;
               v.s17   := '1';
            when AHBL =>
               v.state := AHBM;
               v.s17   := '0';
            when AHBM =>
               v.state := ALBH;
               v.s17   := '1';
            when ALBH =>
               v.state := AHBH;
               v.s17   := '0';
               v.z     := '1';
            when AHBH =>
               v.state := CADD;
               v.z     := '0';
            when CADD =>
               v.state := DONE;
            when DONE =>
         end case;
      end if;

      rin <= v;
   end process P_CMB;

   P_SEQ : process ( clk ) is
   begin
      if ( rising_edge( clk ) ) then
         if ( rst = '1' ) then
            r <= REG_INIT_C;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process P_SEQ;

   U_DSP : entity work.MuluSeq21x17Dsp
      generic map (
         TPD_G           => TPD_G
      )
      port map (
         clk             => clk,
         rst             => rst,
         rstpm           => trg,
         s17             => r.s17,
         z               => r.z,
         a               => muxA,
         b               => muxB,
         c(46 downto 38) => (others => '0'),
         c(37 downto  0) => c,
         cec             => trg,
         p               => pLoc         
      );

   p   <= resize(pLoc, p'length);

   P_DON : process( r ) is
   begin
      if ( r.state = DONE ) then
         don <= '1';
      else
         don <= '0';
      end if;
   end process P_DON;

end architecture Impl;
