
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

include $(GNUSTEP_MAKEFILES)/common.make

# The application to be compiled
SERVICE_NAME = thumbnailer

thumbnailer_HAS_RESOURCE_BUNDLE = yes

#
# subprojects
#
SUBPROJECTS = ImageThumbnailer

# The Objective-C source files to be compiled
thumbnailer_OBJC_FILES = main.m

thumbnailer_RESOURCE_FILES = ImageThumbnailer/ImageThumbnailer.thumb

-include GNUmakefile.preamble
-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/tool.make
include $(GNUSTEP_MAKEFILES)/service.make
include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.local.service
-include GNUmakefile.postamble

