
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = Operation
VERSION = 0.7

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

ifeq ($(FOUNDATION_LIB), apple)
  GNUSTEP_INSTALLATION_DIR = /
endif

# SUBPROJECTS = ContentViewers

#
# MAIN APP
#
APP_NAME = Operation
Operation_PRINCIPAL_CLASS = Operation
Operation_APPLICATION_ICON=Operation.tiff

Operation_HAS_RESOURCE_BUNDLE = yes

Operation_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/English.lproj 

Operation_LANGUAGES = Resources/English 

# The Objective-C source files to be compiled

Operation_OBJC_FILES = main.m \
                 Operation.m \
                 FileOpInfo.m \
                 Preferences/OperationPrefs.m \
                 Functions.m 
						 
-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make

include $(GNUSTEP_MAKEFILES)/application.make

-include GNUmakefile.postamble
