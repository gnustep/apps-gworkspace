# Install into the system root by default
GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
RPM_DISABLE_RELOCATABLE=YES

include $(GNUSTEP_MAKEFILES)/common.make

ifeq ($(findstring darwin, $(GNUSTEP_TARGET_OS)), darwin)
  TOOL_NAME = gmdfind
else
  TOOL_NAME = mdfind
endif

$(TOOL_NAME)_OBJC_FILES = \
mdfind.m 

$(TOOL_NAME)_TOOL_LIBS += -lMDKit
    				 
-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/tool.make

-include GNUmakefile.postamble
