# Install into the system root by default
GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
RPM_DISABLE_RELOCATABLE=YES

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = GMDSClient
VERSION = 0.1

APP_NAME = GMDSClient
GMDSClient_PRINCIPAL_CLASS = GMDSClient
GMDSClient_APPLICATION_ICON=GMDSClient.tiff

GMDSClient_HAS_RESOURCE_BUNDLE = yes

GMDSClient_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/English.lproj 

GMDSClient_LANGUAGES = Resources/English 

# The Objective-C source files to be compiled

GMDSClient_OBJC_FILES = main.m \
                 GMDSClient.m 

ADDITIONAL_GUI_LIBS += -lFSNode -lMDKit
						 
-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/application.make

-include GNUmakefile.postamble
