
GNUSTEP_MAKEFILES = $(GNUSTEP_SYSTEM_ROOT)/Makefiles

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

include $(GNUSTEP_MAKEFILES)/common.make
include Version

FRAMEWORK_NAME = FSNode

FSNode_OBJC_FILES = \
         FSNode.m \
         FSNodeRep.m \
         FSNFunctions.m \
         FSNTextCell.m \
         FSNBrowserCell.m \
         FSNBrowserScroll.m \
         FSNBrowserMatrix.m \
         FSNBrowserColumn.m \
         FSNBrowser.m \
         FSNIcon.m \
         FSNIconsView.m \
         FSNListView.m 
                
FSNode_HEADER_FILES = \
         FSNode.h \
         FSNodeRep.h \
         FSNFunctions.h \
         FSNTextCell.h \
         FSNBrowserCell.h \
         FSNBrowserScroll.h \
         FSNBrowserMatrix.h \
         FSNBrowserColumn.h \
         FSNBrowser.h \
         FSNIcon.h \
         FSNIconsView.h \
         FSNListView.m 
        
FSNode_HAS_RESOURCE_BUNDLE = yes                                          
        
FSNode_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/English.lproj 

FSNode_LANGUAGES = Resources/English 

#FSNode_LOCALIZED_RESOURCE_FILES = Localizable.strings  

SUBPROJECTS = ExtendedInfo 

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/framework.make

include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.postamble
