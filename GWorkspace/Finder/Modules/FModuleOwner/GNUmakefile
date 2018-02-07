
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = FModuleOwner
BUNDLE_EXTENSION = .finder

FModuleOwner_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

FModuleOwner_OBJC_FILES = FModuleOwner.m 

FModuleOwner_PRINCIPAL_CLASS = FModuleOwner

FModuleOwner_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/FModuleOwner.gorm

include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

include GNUmakefile.postamble

