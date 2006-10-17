
# Install into the system root by default
GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
RPM_DISABLE_RELOCATABLE=YES

include $(GNUSTEP_MAKEFILES)/common.make

# The application to be compiled
SERVICE_NAME = thumbnailer

#
# subprojects
#
SUBPROJECTS = ImageThumbnailer

# The Objective-C source files to be compiled
thumbnailer_OBJC_FILES = main.m

-include GNUmakefile.preamble
-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/tool.make
include $(GNUSTEP_MAKEFILES)/service.make
include $(GNUSTEP_MAKEFILES)/bundle.make
include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.local.service
-include GNUmakefile.postamble

