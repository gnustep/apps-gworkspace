
include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

TOOL_NAME = resizer

OBJCFLAGS += -Wall

resizer_OBJC_FILES = Resizer.m 

ADDITIONAL_TOOL_LIBS += -lgnustep-gui $(SYSTEM_LIBS)

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/tool.make

-include GNUmakefile.postamble

