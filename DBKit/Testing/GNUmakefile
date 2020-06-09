PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = dbtest

dbtest_OBJC_FILES = dbtest.m \
test1.m \
test2.m \
test3.m \
test4.m \
test5.m \
test6.m 

ADDITIONAL_LIB_DIRS += -lDBKit

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/tool.make

-include GNUmakefile.postamble

