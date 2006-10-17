
# Install into the system root by default
GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
RPM_DISABLE_RELOCATABLE=YES

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = XDesktopWindow

OBJCFLAGS += -Wall

XDesktopWindow_OBJC_FILES = XDesktopWindow.m 

XDesktopWindow_PRINCIPAL_CLASS = XDesktopWindow

ADDITIONAL_GUI_LIBS += -lX11

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

