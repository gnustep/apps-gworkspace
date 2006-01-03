
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

include $(GNUSTEP_MAKEFILES)/common.make

FRAMEWORK_NAME = Operation
include Version

Operation_PRINCIPAL_CLASS = Operation
Operation_HAS_RESOURCE_BUNDLE = yes

Operation_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/English.lproj 

Operation_LANGUAGES = Resources/English 

# The Objective-C source files to be compiled

Operation_OBJC_FILES = \
                 Operation.m \
                 FileOpInfo.m \
                 Functions.m 

Operation_HEADER_FILES = \
         Operation.h 
						 
-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/framework.make

-include GNUmakefile.postamble
