
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = GWRemote
VERSION = 0.1

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

ifeq ($(FOUNDATION_LIB), apple)
  GNUSTEP_INSTALLATION_DIR = /
endif

#
# subprojects
#
SUBPROJECTS = GWRemote \
	      gwsd 
						 
-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.postamble
