
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECTS = Extractors

TOOL_NAME = mdextractor

mdextractor_OBJC_FILES = mdextractor.m \
                  updater.m 

mdextractor_TOOL_LIBS += -lgnustep-gui
mdextractor_TOOL_LIBS += -L../../../GWMetadata/MDKit/MDKit.framework -lMDKit
mdextractor_TOOL_LIBS += -L../../../DBKit/$(GNUSTEP_OBJ_DIR) -lDBKit
mdextractor_TOOL_LIBS += -L../../../FSNode/FSNode.framework -lFSNode
ADDITIONAL_INCLUDE_DIRS += -I../../../GWMetadata/MDKit
ADDITIONAL_INCLUDE_DIRS += -I../../../GWMetadata/gmds
ADDITIONAL_INCLUDE_DIRS += -I../../../DBKit

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/tool.make

include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.postamble

