
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = SoundViewer
BUNDLE_EXTENSION = .inspector

SoundViewer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

SoundViewer_OBJC_FILES = SoundViewer.m 

SoundViewer_PRINCIPAL_CLASS = SoundViewer

SoundViewer_RESOURCE_FILES = Images/* \
                             InspectorInfo.plist \
                             Resources/English.lproj \

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

