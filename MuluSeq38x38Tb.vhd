library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MuluSeq38x38Tb is
end entity MuluSeq38x38Tb;

architecture Impl of MuluSeq38x38Tb is

   signal clk : std_logic := '0';

   signal a : unsigned(37 downto 0) := x"1234_5678_9" & "00";
   signal b : unsigned(37 downto 0) := x"a987_6543_2" & "00";

   signal p,ph : unsigned(37 downto 0);

   signal t : std_logic := '0';

   signal d : std_logic;

   signal running : boolean := true;

   signal cnt     : natural := 0;

   impure function check return boolean is
      variable dif, exp : unsigned(37 downto 0);
      variable rval     : boolean;
   begin
      exp := resize( shift_right( a*b, 38 ), 38 );
      if ( p > exp ) then
         dif := p - exp;
      else
         dif := exp - p;
      end if;
      rval := dif < 4;
      return rval;
   end function check;

begin

   P_CLK : process
   begin
     if (running) then
        clk <= not clk;
        wait for 10 ns;
     else
        wait;
     end if;
   end process P_CLK;

   P_CNT : process( clk ) is
      variable v : natural;
   begin
      if ( rising_edge( clk ) ) then
         v := cnt + 1;
         case (cnt) is
            when 4 =>
               t <= '1';
            when 8 =>
               t <= '0';
               if (d /= '1') then
                  v := cnt;
               else
                  ph <= p;
                  assert ( check ) severity failure;
               end if;

            when 9  =>
               a <= x"40444_4321" & "11";
               b <= x"5aa5a_a5a5" & "01";
               t <= '1';
               assert p = ph severity failure;

            when 11 =>
               t <= '0';
               if (d /= '1') then
                  v := cnt;
               else
                  ph <= p;
                  assert ( check ) severity failure;
               end if;

            when 20 =>
               running <= false; 

            when others =>
         end case;
         cnt <= v;
      end if;
   end process P_CNT;


   U_DUT : entity work.MuluSeq38x38
      port map (
         clk => clk,
         rst => '0',
         trg => t,
         a   => a,
         b   => b,
         p   => p,
         don => d
      );
end architecture Impl;
