include $(GNUSTEP_MAKEFILES)/common.make

include ../inspector.make

ifneq ($(PDFKIT), 0)
SUBPROJECTS = \
  ImageViewer \
  SoundViewer \
  AppViewer \
  RtfViewer \
  PdfViewer \
  NSTIFFViewer \
  NSRTFViewer \
  NSColorViewer \
  IBViewViewer
else
SUBPROJECTS = \
  ImageViewer \
  SoundViewer \
  AppViewer \
  RtfViewer \
  NSTIFFViewer \
  NSRTFViewer \
  NSColorViewer \
  IBViewViewer
endif

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.postamble

