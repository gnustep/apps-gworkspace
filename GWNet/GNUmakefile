
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = GWNet
VERSION = 0.1

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

SUBPROJECTS = Handlers/smbfileop \
              Handlers/ftpfileop

#
# MAIN APP
#
APP_NAME = GWNet
GWNet_PRINCIPAL_CLASS = GWNet
GWNet_APPLICATION_ICON=GWNet.tiff

GWNet_HAS_RESOURCE_BUNDLE = yes

GWNet_RESOURCE_FILES = \
    Resources/Icons/* \
    Resources/English.lproj 
    
GWNet_LANGUAGES = Resources/English 

# The Objective-C source files to be compiled

GWNet_OBJC_FILES = main.m \
                   GWNet.m \
                   Dialogs/OpenUrlDlog.m \
                   GWNetFunctions.m \
                   externs.m \
                   Viewers/Common/FileOpInfo.m \
                   Viewers/FTPViewer/FTPViewer.m \
                   Viewers/SMBViewer/SMBViewer.m \
                   Viewers/Common/AsyncBrowser/Browser.m \
                   Viewers/Common/AsyncBrowser/Column.m \
                   Viewers/Common/AsyncBrowser/Matrix.m \
                   Viewers/Common/AsyncBrowser/Cell.m \
                   Viewers/Common/AsyncBrowser/Icon.m \
                   Viewers/Common/AsyncBrowser/IconLabel.m \
                   Viewers/Common/AsyncBrowser/NameEditor.m \
                   Viewers/Common/AsyncBrowser/Functions.m \
                   Handlers/Dispatcher.m \
                   Handlers/FTPHandler.m \
                   Handlers/SMBHandler.m \
                   Handlers/FileOperation.m 
                   
GWNet_OBJC_LIBS += -lSMBKit
						 
-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/application.make

-include GNUmakefile.postamble
