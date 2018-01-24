
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = IBViewViewer
BUNDLE_EXTENSION = .inspector

IBViewViewer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
IBViewViewer_OBJC_FILES = IBViewViewer.m

IBViewViewer_PRINCIPAL_CLASS = IBViewViewer

IBViewViewer_RESOURCE_FILES = Resources/English.lproj \
InspectorInfo.plist 

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

