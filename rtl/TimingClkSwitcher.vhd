-------------------------------------------------------------------------------
-- File       : TimingClkSwitcher.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Switch Timing Reference Clock; Entity Declaration
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiLiteSequencerPkg.all;

entity TimingClkSwitcher is
   generic (
      TPD_G                  : time := 1 ns;
      CLOCK_AXIL_BASE_ADDR_G : slv(31 downto 0);
      TCASW_AXIL_BASE_ADDR_G : slv(31 downto 0);
      AXIL_FREQ_G            : real
   );
   port (
      axilClk                : in  sl;
      axilRst                : in  sl;

      clkSel                 : in  sl;

      txRst                  : out sl;
      rxRst                  : out sl;

      mAxilReadMaster        : out AxiLiteReadMasterType;
      mAxilReadSlave         : in  AxiLiteReadSlaveType;
      mAxilWriteMaster       : out AxiLiteWriteMasterType;
      mAxilWriteSlave        : in  AxiLiteWriteSlaveType;

      sAxilReadMaster        : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      sAxilReadSlave         : out AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      sAxilWriteMaster       : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      sAxilWriteSlave        : out AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
end entity TimingClkSwitcher;
