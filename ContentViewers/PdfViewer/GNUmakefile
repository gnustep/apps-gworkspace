include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = PdfViewer
BUNDLE_EXTENSION = .inspector

PdfViewer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

#
# Additional libraries
#
ifeq ($(FOUNDATION_LIB), apple)
  ADDITIONAL_GUI_LIBS += -framework GWorkspace
else
  ADDITIONAL_GUI_LIBS += -lGWorkspace
endif

PdfViewer_OBJC_FILES = PdfViewer.m \
		       PSDocument.m 

PdfViewer_C_FILES = ps.c 

PdfViewer_PRINCIPAL_CLASS = PdfViewer

#PdfViewer_LANGUAGES = English Italian Romanian

PdfViewer_RESOURCE_FILES = Images/* \
                           InspectorInfo.plist \
			   papersizes.plist

#PdfViewer_LOCALIZED_RESOURCE_FILES = Localizable.strings

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

