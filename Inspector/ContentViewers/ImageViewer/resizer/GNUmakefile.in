
# Install into the system root by default
GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
RPM_DISABLE_RELOCATABLE=YES

include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = resizer

OBJCFLAGS += -Wall

resizer_OBJC_FILES = Resizer.m 

ADDITIONAL_TOOL_LIBS += -lgnustep-gui $(SYSTEM_LIBS)

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/tool.make

-include GNUmakefile.postamble

