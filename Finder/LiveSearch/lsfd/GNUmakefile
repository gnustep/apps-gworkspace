
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

include $(GNUSTEP_MAKEFILES)/common.make

# The application to be compiled
TOOL_NAME = lsfd

# The Objective-C source files to be compiled

lsfd_OBJC_FILES = lsfd.m lsfolder.m updater.m

# The Resource files to be copied into the app's resources directory

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/tool.make

-include GNUmakefile.postamble

