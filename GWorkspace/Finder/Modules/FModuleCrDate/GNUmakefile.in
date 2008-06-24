# Install into the system root by default
GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
RPM_DISABLE_RELOCATABLE=YES

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = FModuleCrDate
BUNDLE_EXTENSION = .finder

FModuleCrDate_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

FModuleCrDate_OBJC_FILES = FModuleCrDate.m 

FModuleCrDate_PRINCIPAL_CLASS = FModuleCrDate

FModuleCrDate_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/FModuleCrDate.gorm

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

