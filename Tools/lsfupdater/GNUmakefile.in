
# Install into the system root by default
GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
RPM_DISABLE_RELOCATABLE=YES

include $(GNUSTEP_MAKEFILES)/common.make

# The application to be compiled
TOOL_NAME = lsfupdater

# The Objective-C source files to be compiled

lsfupdater_OBJC_FILES = lsfupdater.m 

ADDITIONAL_TOOL_LIBS += -lgnustep-gui $(SYSTEM_LIBS)

# The Resource files to be copied into the app's resources directory

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/tool.make

-include GNUmakefile.postamble

