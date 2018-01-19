
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

ifeq ($(findstring darwin, $(GNUSTEP_TARGET_OS)), darwin)
  TOOL_NAME = gmdfind
else
  TOOL_NAME = mdfind
endif

$(TOOL_NAME)_OBJC_FILES = \
mdfind.m 

$(TOOL_NAME)_TOOL_LIBS += -L../../../GWMetadata/MDKit/MDKit.framework -lMDKit
$(TOOL_NAME)_TOOL_LIBS += -L../../../DBKit/$(GNUSTEP_OBJ_DIR) -lDBKit
$(TOOL_NAME)_TOOL_LIBS += -L../../../FSNode/FSNode.framework -lFSNode
ADDITIONAL_INCLUDE_DIRS += -I../../../GWMetadata/MDKit
    				 
-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/tool.make

-include GNUmakefile.postamble
