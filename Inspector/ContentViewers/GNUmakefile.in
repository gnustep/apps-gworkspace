# Install into the system root by default
GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
RPM_DISABLE_RELOCATABLE=YES

include $(GNUSTEP_MAKEFILES)/common.make

include ../inspector.make

ifneq ($(PDFKIT),no)
SUBPROJECTS = \
  FolderViewer \
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
  FolderViewer \
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

