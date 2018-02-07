
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

LIBRARY_VAR  = DBKIT
LIBRARY_NAME = libDBKit

libDBKit_OBJC_FILES = \
DBKBTree.m \
DBKBTreeNode.m \
DBKFreeNodesPage.m \
DBKFixLenRecordsFile.m \
DBKVarLenRecordsFile.m \
DBKPathsTree.m

libDBKit_HEADER_FILES = \
DBKBTree.h \
DBKBTreeNode.h \
DBKFixLenRecordsFile.h \
DBKVarLenRecordsFile.h \
DBKPathsTree.h

libDBKit_HEADER_FILES_DIR = .
libDBKit_HEADER_FILES_INSTALL_DIR=DBKit

LIBRARIES_DEPEND_UPON += $(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)

ifeq ($(findstring darwin, $(GNUSTEP_TARGET_OS)), darwin)
  ifeq ($(OBJC_RUNTIME_LIB), gnu)
    SHARED_LD_POSTFLAGS += -lgnustep-base
  endif
endif

include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.preamble
-include GNUmakefile.local
-include GNUmakefile.postamble

