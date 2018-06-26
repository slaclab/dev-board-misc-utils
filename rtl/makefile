SRCS  = StdRtlPkg.vhd
SRCS += TextUtilPkg.vhd
SRCS += AxiLitePkg.vhd
SRCS += AxiLiteMasterPkg.vhd
SRCS += AxiLiteMaster.vhd
SRCS += AxiLiteRegs.vhd
SRCS += AxiLiteSequencerPkg.vhd
SRCS += AxiLiteSequencer.vhd
SRCS += AxiLiteSequencerTb.vhd
SRCS += MuluSeq21x17DspPrim.vhd
SRCS += MuluSeq38x38.vhd
SRCS += MuluSeq38x38Tb.vhd
SRCS += I2cPkg.vhd
SRCS += TimingClkSwitcher.vhd
SRCS += TimingClkSwitcherSi570.vhd
SRCS += stdlib.vhd
SRCS += I2cSlave.vhd
SRCS += I2cRegSlave.vhd
SRCS += i2c_master_bit_ctrl.vhd
SRCS += i2c_master_byte_ctrl.vhd
SRCS += I2cMaster.vhd
SRCS += I2cRegMaster.vhd
SRCS += I2cRegMasterAxiBridge.vhd
SRCS += AxiI2cRegMaster.vhd
SRCS += TimingClkSwitcherTb.vhd

VPATH  = surf/base/general/rtl
VPATH += surf/axi/rtl
VPATH += surf/protocols/i2c/rtl

OBJS=$(SRCS:%.vhd=%.o)

all: $(OBJS)

GHDLFLAGS=--ieee=synopsys -fexplicit

%.o: %.vhd
	ghdl -a $(GHDLFLAGS) $^


clean:
	$(RM) $(OBJS)

%tb %Tb:
	ghdl -m $(GHDLFLAGS) $@
