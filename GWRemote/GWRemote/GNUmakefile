PACKAGE_NEEDS_CONFIGURE = YES

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = GWRemote
VERSION = 0.1

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

#
# MAIN APP
#
APP_NAME = GWRemote
GWRemote_PRINCIPAL_CLASS = GWRemote
GWRemote_APPLICATION_ICON=GWRemote.tiff

GWRemote_HAS_RESOURCE_BUNDLE = yes

#
# Additional libraries
#
ADDITIONAL_GUI_LIBS += -lGWorkspace

GWRemote_RESOURCE_FILES = \
    Resources/Icons/* \
    Resources/English.lproj 
    
GWRemote_LANGUAGES = Resources/English 

GWRemote_LOCALIZED_RESOURCE_FILES = Localizable.strings \
                                    LoginWindow.gorm \
                                    RemoteEditor.gorm \
                                    FindWindow.gorm \
                                    FileOperationWin.gorm \
                                    PrefWindow.gorm \
                                    GWSDServerPref.gorm 

# The Objective-C source files to be compiled

GWRemote_OBJC_FILES = main.m \
                      GWRemote.m \
                      Viewer/ViewerWindow.m \
                      Viewer/GWSplitView.m \
                      Viewer/Viewer.m \
                      Viewer/Shelf.m \
                      Viewer/ShelfIcon.m \
                      FileOpProgress.m \
                      LoginWindow.m \
                      RemoteEditor/RemoteEditor.m \
                      RemoteEditor/RemoteEditorView.m \
                      RemoteTerminal/RemoteTerminal.m \
                      RemoteTerminal/RemoteTerminalView.m \
                      Preferences/PrefController.m \
                      Preferences/GWSDServerPref.m


						 
-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make

include $(GNUSTEP_MAKEFILES)/application.make

-include GNUmakefile.postamble
