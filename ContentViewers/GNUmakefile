include $(GNUSTEP_MAKEFILES)/common.make

include ../gworkspace.make

ifneq ($(GS_PATH), none)
SUBPROJECTS = \
  FolderViewer \
  ImageViewer \
  AppViewer \
  SoundViewer \
  RtfViewer \
  PlistViewer \
  StringsViewer \
  InspectorViewer \
  PdfViewer \
  PasteboardViewer 
else
SUBPROJECTS = \
  FolderViewer \
  ImageViewer \
  AppViewer \
  SoundViewer \
  RtfViewer \
  PlistViewer \
  StringsViewer \
  InspectorViewer \
  PasteboardViewer 
endif

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.postamble

