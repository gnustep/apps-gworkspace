
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = PdfViewer
BUNDLE_EXTENSION = .inspector

PdfViewer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

PdfViewer_GUI_LIBS += -lPDFKit

PdfViewer_OBJC_FILES = PdfViewer.m 

PdfViewer_PRINCIPAL_CLASS = PdfViewer

#PdfViewer_LANGUAGES = English 
PdfViewer_RESOURCE_FILES = Images/* \
                           InspectorInfo.plist \
                           Resources/English.lproj 

#PdfViewer_LOCALIZED_RESOURCE_FILES = Localizable.strings

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

