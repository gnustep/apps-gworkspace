PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = XDesktopWindow

OBJCFLAGS += -Wall

XDesktopWindow_OBJC_FILES = XDesktopWindow.m 

XDesktopWindow_PRINCIPAL_CLASS = XDesktopWindow

ADDITIONAL_GUI_LIBS += -lX11

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

