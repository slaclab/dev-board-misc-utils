-------------------------------------------------------------------------------
-- File       : PWMController.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simple PWM Controller
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
use ieee.math_real.log2;
use ieee.math_real.floor;

entity PWMController is
   generic (
      TPD_G          : time     := 1 ns;
      PRESC_G        : natural  := 0;
      WIDTH_G        : positive := 8
   );
   port (
      clk            : in  std_logic;
      rst            : in  std_logic;
      pulseWidth     : in  unsigned(WIDTH_G - 1 downto 0);
      strobe         : out std_logic;
      modOut         : out std_logic
   );
end entity PWMController;

architecture Impl of PWMController is
   signal cnt : unsigned(WIDTH_G - 1 downto 0) := (others => '0');

   signal cen : std_logic := '1';

   signal pwm : std_logic := '0';
begin

   GEN_PRESC : if ( PRESC_G > 1 ) generate
      constant PRESC_W_C : positive := positive( floor( log2( real(PRESC_G) ) ) ) + 1;
      signal   presc     : unsigned( PRESC_W_C - 1 downto 0) := (others => '0');
   begin
      P_PRESC : process( clk ) is
      begin
         if ( rising_edge( clk ) ) then
            if ( rst = '1' or presc = PRESC_G - 1 ) then
               presc <= (others => '0');
               cen   <= '1';
            else
               presc <= presc + 1 after TPD_G;
               cen   <= '0'       after TPD_G;
            end if;
         end if;
      end process P_PRESC;
   end generate;

   P_CNT : process( clk ) is
   begin
      if ( rising_edge( clk ) ) then
         if ( rst = '1' ) then
            cnt <= (others => '0');
         elsif ( cen = '1' ) then
            -- cover [0..1] => [0..(2**WIDTH_G-1)] (include interval boundaries)
            if ( cnt = to_unsigned( 2**WIDTH_G - 2, WIDTH_G ) ) then
               cnt <= cnt + 2 after TPD_G;
            else
               cnt <= cnt + 1 after TPD_G;
            end if;
         end if;
      end if;
   end process P_CNT;

   P_PWM : process( clk ) is
   begin
      if ( rising_edge( clk ) ) then
         if ( rst = '1' ) then
            pwm <= '0';
         else
            if ( cen = '1' ) then
               if ( cnt < pulseWidth ) then
                  pwm <= '1' after TPD_G;
               else
                  pwm <= '0' after TPD_G;
               end if;
            end if;
         end if;
      end if;
   end process P_PWM;

   modOut <= pwm;
   strobe <= cen;
end architecture Impl;
