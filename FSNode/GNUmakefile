
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
         FSNIcon.m \
         FSNIconContainer.m 
                
FSNode_HEADER_FILES = \
         FSNode.h \
         FSNodeRep.h \
         FSNFunctions.h \
         FSNTextCell.h \
         FSNBrowserCell.h \
         FSNIcon.h \
         FSNIconContainer.h 
        
FSNode_HAS_RESOURCE_BUNDLE = yes                                          
        
FSNode_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/English.lproj 

FSNode_LANGUAGES = Resources/English 

#FSNode_LOCALIZED_RESOURCE_FILES = Localizable.strings  

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/framework.make

-include GNUmakefile.postamble
