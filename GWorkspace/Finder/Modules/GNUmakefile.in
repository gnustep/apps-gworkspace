# Install into the system root by default
GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
RPM_DISABLE_RELOCATABLE=YES

include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECTS = \
    FModuleName \
    FModuleKind \
    FModuleSize \
    FModuleOwner \
    FModuleCrDate \
    FModuleModDate \
    FModuleContents \
    FModuleAnnotations


-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.postamble

