
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = GWRemote
VERSION = 0.1

ifeq ($(FOUNDATION_LIB), gnu)
  GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)
endif

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
