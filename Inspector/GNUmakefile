
PACKAGE_NEEDS_CONFIGURE = YES

PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make
include inspector.make

SUBPROJECTS = ContentViewers

FRAMEWORK_NAME = Inspector
include Version

Inspector_PRINCIPAL_CLASS = Inspector
Inspector_HAS_RESOURCE_BUNDLE = yes

ifneq ($(PDFKIT),no)
  Inspector_GUI_LIBS += -lPDFKit
  ADDITIONAL_LDFLAGS = -lPDFKit
endif

Inspector_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/English.lproj 

Inspector_LANGUAGES = Resources/English 

# The Objective-C source files to be compiled

Inspector_OBJC_FILES = \
         Inspector.m \
         Attributes.m \
         Contents.m \
         Tools.m \
         Annotations.m \
         IconView.m \
         TimeDateView.m \
         Functions.m

Inspector_HEADER_FILES = \
         Inspector.h \
         ContentViewersProtocol.h

ifeq ($(findstring darwin, $(GNUSTEP_TARGET_OS)), darwin)
  ifeq ($(OBJC_RUNTIME_LIB), gnu)
    SHARED_LD_POSTFLAGS += -lgnustep-base -lgnustep-gui -lFSNode
  endif
endif

LIBRARIES_DEPEND_UPON = $(GUI_LIBS) $(FND_LIBS) $(OBJC_LIBS) -lFSNode

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/framework.make

include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.postamble


