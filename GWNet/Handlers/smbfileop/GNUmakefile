
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

include $(GNUSTEP_MAKEFILES)/common.make

# The application to be compiled
TOOL_NAME = smbfileop

# The Objective-C source files to be compiled

smbfileop_OBJC_FILES = smbfileop.m

smbfileop_OBJC_LIBS += -lSMBKit

# The Resource files to be copied into the app's resources directory

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/tool.make

-include GNUmakefile.postamble

