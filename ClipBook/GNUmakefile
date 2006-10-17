# Install into the system root by default
GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
RPM_DISABLE_RELOCATABLE=YES

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = ClipBook
VERSION = 0.6

#
# MAIN APP
#
APP_NAME = ClipBook
ClipBook_PRINCIPAL_CLASS = ClipBook
ClipBook_APPLICATION_ICON=ClipBook.tiff

ClipBook_HAS_RESOURCE_BUNDLE = yes

ClipBook_RESOURCE_FILES = Resources/Icons/* \
		          Resources/English.lproj 

ClipBook_LANGUAGES = Resources/English

ClipBook_LOCALIZED_RESOURCE_FILES = Localizable.strings \
                                    ClipBookWindow.gorm 

# The Objective-C source files to be compiled
ClipBook_OBJC_FILES = main.m \
                      ClipBook.m \
                      ClipBookWindow.m \
                      PBViewer.m \
                      Functions.m
						 
-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/application.make

-include GNUmakefile.postamble
