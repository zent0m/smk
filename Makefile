CC= sdcc
ASM = sdas8051
SDAR ?= sdar -rc
OBJCOPY = objcopy
PACKIHX = packihx
FLASHER = sinowealth-kb-tool write -p nuphy-air60

SRCDIR = src
OBJDIR = obj
BINDIR = bin

FAMILY = mcs51
PROC = mcs51

FREQ_SYS ?= 24000000 # 24Mhz, could be keyboard specific
WATHCDOG_ENABLE ?= 1 # could be keyboard specific
XRAM_SIZE ?= 0x1000
XRAM_LOC ?= 0x0000
CODE_SIZE ?= 0xf000 # 61440 bytes (leaving the remaining 4096 for bootloader)

SMK_VERSION ?= alpha

# Ease backup & restore process by keeping same vid & pid as nuphy-air60
USB_VID ?= 0x05ac
USB_PID ?= 0x024f

DEBUG ?= 1

CFLAGS := -V -mmcs51 --model-small \
	--xram-size $(XRAM_SIZE) --xram-loc $(XRAM_LOC) \
	--code-size $(CODE_SIZE) \
	--std-c2x \
	-I$(ROOT_DIR)../include \
	-DDEBUG=$(DEBUG) \
	-DFREQ_SYS=$(FREQ_SYS) \
	-DWATCHDOG_ENABLE=$(WATHCDOG_ENABLE) \
	-DUSB_VID=$(USB_VID) \
	-DUSB_PID=$(USB_PID) \
	-DSMK_VERSION=$(SMK_VERSION)
LFLAGS := $(CFLAGS)
AFLAGS := -plosgff

# TODO: this should be selected based on the target being built
LAYOUT_SOURCES := $(wildcard $(SRCDIR)/keyboards/nuphy-air60/layouts/default/*.c)
KEYBOARD_SOURCES := $(wildcard $(SRCDIR)/keyboards/nuphy-air60/*.c)

# main.c has to be the first file
MAIN_SOURCES := $(SRCDIR)/main.c \
	$(filter-out $(SRCDIR)/main.c, $(wildcard $(SRCDIR)/*.c)) \
	$(wildcard $(SRCDIR)/smk/*.c) \
	$(KEYBOARD_SOURCES) \
	$(LAYOUT_SOURCES)
MAIN_OBJECTS := $(MAIN_SOURCES:$(SRCDIR)/%.c=$(OBJDIR)/%.rel)

LIBSINO8051_SOURCES := $(wildcard $(SRCDIR)/lib/sh68f90a/*.c)
LIBSINO8051_OBJECTS := $(LIBSINO8051_SOURCES:$(SRCDIR)/lib/sh68f90a/%.c=$(OBJDIR)/lib/sh68f90a/%.rel)

USER_SOURCES := $(wildcard $(SRCDIR)/user/*.c)
USER_OBJECTS := $(USER_SOURCES:$(SRCDIR)/user/%.c=$(OBJDIR)/user/%.rel)

KEYBOARDS_LAYOUTS = nuphy-air60_default

.PHONY: all
all: $(KEYBOARDS_LAYOUTS:%=$(BINDIR)/%.hex)

.PHONY: clean
clean:
	rm -rf $(BINDIR) $(OBJDIR)

.PHONY: %_flash
%_flash: $(BINDIR)/%.hex
	$(FLASHER) $(BINDIR)/%.hex

$(OBJDIR)/%.rel: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	$(CC) -m$(FAMILY) -l$(PROC) $(CFLAGS) -c $< -o $@

$(BINDIR)/overridable.lib: $(OVERRIDABLE_OBJECTS)
	@mkdir -p $(@D)
	$(SDAR) $@ $^

$(BINDIR)/sino8051.lib: $(LIBSINO8051_OBJECTS)
	@mkdir -p $(@D)
	$(SDAR) $@ $^

$(BINDIR)/%.ihx: $(MAIN_OBJECTS) $(BINDIR)/sino8051.lib $(BINDIR)/overridable.lib
	@mkdir -p $(@D)
	$(CC) -m$(FAMILY) -l$(PROC) $(LFLAGS) -o $@ $(MAIN_OBJECTS) -L$(BINDIR) -loverridable -lsino8051

$(BINDIR)/%.hex: $(BINDIR)/%.ihx
	${PACKIHX} < $< > $@

$(BINDIR)/%.bin: $(BINDIR)/%.hex
	$(OBJCOPY) -I ihex -O binary $< $@
