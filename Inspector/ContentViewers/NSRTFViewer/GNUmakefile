
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = NSRTFViewer
BUNDLE_EXTENSION = .inspector

NSRTFViewer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
NSRTFViewer_OBJC_FILES = NSRTFViewer.m

NSRTFViewer_PRINCIPAL_CLASS = NSRTFViewer

#NSRTFViewer_LANGUAGES = English

#NSRTFViewer_LOCALIZED_RESOURCE_FILES = Localizable.strings

NSRTFViewer_RESOURCE_FILES = InspectorInfo.plist

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

