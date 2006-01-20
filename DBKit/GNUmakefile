
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = DBKit
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
                        
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.preamble
-include GNUmakefile.local
-include GNUmakefile.postamble

