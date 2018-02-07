
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make
include Version

FRAMEWORK_NAME = FSNode

FSNode_OBJC_FILES = \
         FSNode.m \
         FSNodeRep.m \
         FSNodeRepIcons.m \
         FSNFunctions.m \
         FSNTextCell.m \
         FSNBrowserCell.m \
         FSNBrowserScroll.m \
         FSNBrowserMatrix.m \
         FSNBrowserColumn.m \
         FSNBrowser.m \
         FSNIcon.m \
         FSNIconsView.m \
         FSNListView.m \
         FSNPathComponentsViewer.m \


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
         FSNListView.h \
         FSNPathComponentsViewer.h \


FSNode_HAS_RESOURCE_BUNDLE = yes                                          

FSNode_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/*.lproj \

FSNode_LANGUAGES = \
	English \
	Italian \
	German \
	French \
	Spanish \

LIBRARIES_DEPEND_UPON += $(GUI_LIBS) $(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)

ifeq ($(findstring darwin, $(GNUSTEP_TARGET_OS)), darwin)
  ifeq ($(OBJC_RUNTIME_LIB), gnu)
    SHARED_LD_POSTFLAGS += -lgnustep-base -lgnustep-gui
  endif
endif

SUBPROJECTS = ExtendedInfo 

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/framework.make

include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.postamble
