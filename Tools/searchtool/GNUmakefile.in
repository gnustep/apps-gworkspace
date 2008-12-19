
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

# The application to be compiled
TOOL_NAME = searchtool

# The Objective-C source files to be compiled

searchtool_OBJC_FILES = searchtool.m 

ADDITIONAL_TOOL_LIBS += -lgnustep-gui $(SYSTEM_LIBS)

# The Resource files to be copied into the app's resources directory

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/tool.make

-include GNUmakefile.postamble

