
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECTS = Stemmer \
Extractors

TOOL_NAME = mdextractor

mdextractor_OBJC_FILES = mdextractor.m \
                  updater.m 

mdextractor_TOOL_LIBS += -lgnustep-gui
mdextractor_TOOL_LIBS += -lSQLite
mdextractor_TOOL_LIBS += -lDBKit

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/tool.make

include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.postamble

