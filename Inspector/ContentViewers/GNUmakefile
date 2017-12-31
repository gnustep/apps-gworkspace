
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

include ../inspector.make

SUBPROJECTS = \
  FolderViewer \
  ImageViewer \
  SoundViewer \
  AppViewer \
  RtfViewer \
  NSTIFFViewer \
  NSRTFViewer \
  NSColorViewer \
  IBViewViewer

ifneq ($(PDFKIT),no)
SUBPROJECTS += PdfViewer
endif

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.postamble

