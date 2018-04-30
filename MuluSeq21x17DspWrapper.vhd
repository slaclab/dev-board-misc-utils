library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity MuluSeq21x17Dsp is
   generic (
      TPD_G           : time    := 1 ns
   );
   port (
      clk    : in  std_logic;
      rst    : in  std_logic;
      rstpm  : in  std_logic;
      s17    : in  std_logic;
      z      : in  std_logic := '0';
      cec    : in  std_logic := '0';
      a      : in  unsigned(20 downto 0);
      b      : in  unsigned(16 downto 0);
      c      : in  unsigned(46 downto 0) := (others => '0');
      p      : out unsigned(46 downto 0)
   );
end entity MuluSeq21x17Dsp;

architecture DspWrapper of MuluSeq21x17Dsp is

   signal a_i : std_logic_vector(29 downto 0);
   signal b_i : std_logic_vector(17 downto 0);
   signal c_i : std_logic_vector(47 downto 0);
   signal p_i : std_logic_vector(47 downto 0);
   signal z48 : std_logic_vector(47 downto 0) := (others => '0');
   signal z30 : std_logic_vector(29 downto 0) := (others => '0');
   signal z25 : std_logic_vector(24 downto 0) := (others => '0');
   signal z18 : std_logic_vector(17 downto 0) := (others => '0');
   signal opm : std_logic_vector( 6 downto 0) := (others => '0');

   signal rpm : std_logic;

begin

   a_i(29 downto 21) <= (others => '0');
   a_i(20 downto  0) <= std_logic_vector(a);

   b_i(17 downto 17) <= (others => '0');
   b_i(16 downto  0) <= std_logic_vector(b);

   c_i(47 downto 47) <= (others => '0');
   c_i(46 downto  0) <= std_logic_vector(c);

   p                 <= unsigned(p_i(46 downto 0));

   rpm               <= rst or rstpm;

   P_OPMODE : process( z, s17 ) is
   begin
      if ( z = '1' ) then
         opm <= "0101100";   -- Z => P, Y => C, X => 0
      else
         if ( s17 = '1' ) then
           opm <= "1100101"; -- Z => P>>17, X/Y => M
         else
           opm <= "0100101"; -- Z => P    , X/Y => M
         end if;
      end if;
   end process P_OPMODE;

   U_DSP : DSP48E1
      port map (
         ACOUT          => open,      -- out std_logic_vector(29 downto 0);
         BCOUT          => open,      -- out std_logic_vector(17 downto 0);
         CARRYCASCOUT   => open,      -- out std_ulogic;
         CARRYOUT       => open,      -- out std_logic_vector(3 downto 0);
         MULTSIGNOUT    => open,      -- out std_ulogic;
         OVERFLOW       => open,      -- out std_ulogic;
         P              => p_i,       -- out std_logic_vector(47 downto 0);
         PATTERNBDETECT => open,      -- out std_ulogic;
         PATTERNDETECT  => open,      -- out std_ulogic;
         PCOUT          => open,      -- out std_logic_vector(47 downto 0);
         UNDERFLOW      => open,      -- out std_ulogic;
         A              => a_i,       -- in  std_logic_vector(29 downto 0);
         ACIN           => z30,       -- in  std_logic_vector(29 downto 0);
         ALUMODE        => "0000",    -- in  std_logic_vector(3 downto 0);
         B              => b_i,       -- in  std_logic_vector(17 downto 0);
         BCIN           => z18,       -- in  std_logic_vector(17 downto 0);
         C              => c_i,       -- in  std_logic_vector(47 downto 0);
         CARRYCASCIN    => '0',       -- in  std_ulogic;
         CARRYIN        => '0',       -- in  std_ulogic;
         CARRYINSEL     => "000",     -- in  std_logic_vector(2 downto 0);
         CEA1           => '0',       -- in  std_ulogic;
         CEA2           => '1',       -- in  std_ulogic;
         CEAD           => '0',       -- in  std_ulogic;
         CEALUMODE      => '1',       -- in  std_ulogic;
         CEB1           => '0',       -- in  std_ulogic;
         CEB2           => '1',       -- in  std_ulogic;
         CEC            => cec,       -- in  std_ulogic;
         CECARRYIN      => '1',       -- in  std_ulogic;
         CECTRL         => '1',       -- in  std_ulogic;
         CED            => '0',       -- in  std_ulogic;
         CEINMODE       => '1',       -- in  std_ulogic;
         CEM            => '1',       -- in  std_ulogic;
         CEP            => '1',       -- in  std_ulogic;
         CLK            => clk,       -- in  std_ulogic;
         D              => z25,       -- in  std_logic_vector(24 downto 0);
         INMODE         => "00000",   -- in  std_logic_vector(4 downto 0);
         MULTSIGNIN     => '0',       -- in std_ulogic;
         OPMODE         => opm,       -- in  std_logic_vector(6 downto 0);
         PCIN           => z48,       -- in  std_logic_vector(47 downto 0);
         RSTA           => rst,       -- in  std_ulogic;
         RSTALLCARRYIN  => rst,       -- in  std_ulogic;
         RSTALUMODE     => rst,       -- in  std_ulogic;
         RSTB           => rst,       -- in  std_ulogic;
         RSTC           => rst,       -- in  std_ulogic;
         RSTCTRL        => rst,       -- in  std_ulogic;
         RSTD           => rst,       -- in  std_ulogic;
         RSTINMODE      => rst,       -- in  std_ulogic;
         RSTM           => rpm,       -- in  std_ulogic;
         RSTP           => rpm        -- in  std_ulogic
      );

end architecture DspWrapper;
