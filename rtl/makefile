VIVADO=/opt/Xilinx/Vivado/2017.4/data/vhdl/src/unisims/

SRCS  = StdRtlPkg.vhd
SRCS += TextUtilPkg.vhd
SRCS += AxiLitePkg.vhd
SRCS += AxiLiteMasterPkg.vhd
SRCS += AxiLiteMaster.vhd
SRCS += AxiLiteRegs.vhd
SRCS += AxiLiteSequencerPkg.vhd
SRCS += AxiLiteSequencer.vhd
SRCS += AxiLiteSequencerTb.vhd
SRCS += MuluSeq.vhd
SRCS += MuluSeq21x17Dsp.vhd
SRCS += MuluSeq21x17DspInferred.vhd
SRCS += MuluSeq38x38.vhd
SRCS += MuluSeq38x38SeqImpl.vhd
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
SRCS += TimingClkSwitcherSi570Tb.vhd

VPATH  = surf/base/general/rtl
VPATH += surf/axi/axi-lite/rtl
VPATH += surf/protocols/i2c/rtl
VPATH += $(VIVADO)
VPATH += $(VIVADO)/primitive

OBJS=$(SRCS:%.vhd=%.o)

all: unisim $(OBJS)

USRCS+=$(VIVADO)/unisim_VPKG.vhd
USRCS+=$(VIVADO)/unisim_VCOMP.vhd
USRCS+=$(VIVADO)/primitive/IOBUF.vhd

UOBJS=$(patsubst %.vhd,%.o,$(notdir $(USRCS)))

.PHONY: unisim

unisim: $(UOBJS)

GHDLFLAGS=--ieee=synopsys -fexplicit

$(OBJS): %.o: %.vhd
	ghdl -a $(GHDLFLAGS) $^

$(UOBJS): VPATH=$(VIVADO)

$(UOBJS): %.o: %.vhd
	ghdl -a $(GHDLFLAGS) --work=unisim $^

clean:
	$(RM) $(OBJS) $(UOBJS)
	$(RM) *obj*.cf

%tb %Tb:
	ghdl -m $(GHDLFLAGS) $@
