
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = GWRemote
VERSION = 0.2

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

ifeq ($(FOUNDATION_LIB), apple)
  GNUSTEP_INSTALLATION_DIR = /
endif

#
# MAIN APP
#
APP_NAME = GWRemote
GWRemote_PRINCIPAL_CLASS = GWRemote
GWRemote_APPLICATION_ICON=GWRemote.tiff

GWRemote_HAS_RESOURCE_BUNDLE = yes

GWRemote_RESOURCE_FILES = \
    Resources/Icons/* \
    Resources/English.lproj 
    
GWRemote_LANGUAGES = Resources/English 

# The Objective-C source files to be compiled

GWRemote_OBJC_FILES = main.m \
                      Functions.m \
                      externs.m \
                      GWRemote.m \
                      Viewer/ViewerWindow.m \
                      Viewer/GWSplitView.m \
                      Viewer/Viewer.m \
                      Viewer/Shelf.m \
                      Viewer/ShelfIcon.m \
                      Viewer/Browser.m \
                      Viewer/Cell.m \
                      Viewer/Column.m \
                      Viewer/IconLabel.m \
                      Viewer/Icon.m \
                      Viewer/Matrix.m \
                      Viewer/NameEditor.m \
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
