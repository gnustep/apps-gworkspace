# Install into the system root by default
GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
RPM_DISABLE_RELOCATABLE=YES

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = Recycler
VERSION = 0.7

#
# MAIN APP
#
APP_NAME = Recycler
Recycler_PRINCIPAL_CLASS = Recycler
Recycler_APPLICATION_ICON=Recycler.tiff

Recycler_HAS_RESOURCE_BUNDLE = yes

Recycler_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/English.lproj 

Recycler_LANGUAGES = Resources/English 

# The Objective-C source files to be compiled
Recycler_OBJC_FILES = main.m \
                     Recycler.m \
                     RecyclerView.m \
                     RecyclerIcon.m \
                     Preferences/RecyclerPrefs.m \
                     Dialogs/StartAppWin.m

ADDITIONAL_GUI_LIBS += -lFSNode
						 
-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make

include $(GNUSTEP_MAKEFILES)/application.make

-include GNUmakefile.postamble
