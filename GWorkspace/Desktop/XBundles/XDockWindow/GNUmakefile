
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = XDockWindow

OBJCFLAGS += -Wall

XDockWindow_OBJC_FILES = XDockWindow.m 

XDockWindow_PRINCIPAL_CLASS = XDockWindow

ADDITIONAL_GUI_LIBS += -lX11

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

