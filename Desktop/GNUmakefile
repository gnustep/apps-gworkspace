
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = Desktop
VERSION = 0.7

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

#
# MAIN APP
#
APP_NAME = Desktop
Desktop_PRINCIPAL_CLASS = Desktop
Desktop_APPLICATION_ICON=Desktop.tiff

Desktop_HAS_RESOURCE_BUNDLE = yes

Desktop_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/English.lproj 

Desktop_LANGUAGES = Resources/English 

# The Objective-C source files to be compiled
Desktop_OBJC_FILES = main.m \
                     Desktop.m \
                     DesktopWindow.m \
                     DesktopView.m \
                     Dock/Dock.m \
                     Dock/DockIcon.m \
                     Preferences/DesktopPrefs.m \
                     Dialogs/StartAppWin.m

ADDITIONAL_GUI_LIBS += -lFSNode
						 
-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make

include $(GNUSTEP_MAKEFILES)/application.make

-include GNUmakefile.postamble
