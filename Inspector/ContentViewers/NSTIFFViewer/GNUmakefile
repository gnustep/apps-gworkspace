
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = NSTIFFViewer
BUNDLE_EXTENSION = .inspector

NSTIFFViewer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
NSTIFFViewer_OBJC_FILES = NSTIFFViewer.m

NSTIFFViewer_PRINCIPAL_CLASS = NSTIFFViewer

#NSTIFFViewer_LANGUAGES = English

#NSTIFFViewer_LOCALIZED_RESOURCE_FILES = Localizable.strings

NSTIFFViewer_RESOURCE_FILES = InspectorInfo.plist

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

