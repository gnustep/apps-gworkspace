
PACKAGE_NEEDS_CONFIGURE = YES

PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECTS = MDModules 

# The application to be compiled
TOOL_NAME = ddbd

ddbd_OBJC_FILES = ddbd.m \
DDBPathsManager.m \
DDBDirsManager.m \
DDBMDStorage.m

ddbd_TOOL_LIBS += -lDBKit
ddbd_TOOL_LIBS += -lgnustep-gui $(SYSTEM_LIBS)

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make

include $(GNUSTEP_MAKEFILES)/tool.make

-include GNUmakefile.postamble

