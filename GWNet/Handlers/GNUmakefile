
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECTS = smbfileop \
              ftpfileop

# The application to be compiled
TOOL_NAME = gwnetd

# The Objective-C source files to be compiled

gwnetd_OBJC_FILES = gwnetd.m \
                    Dispatcher.m \
                    FTPHandler.m \
                    SMBHandler.m \
                    FileOperation.m 

gwnetd_OBJC_LIBS += -lSMBKit

# The Resource files to be copied into the app's resources directory

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/tool.make
include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.postamble

