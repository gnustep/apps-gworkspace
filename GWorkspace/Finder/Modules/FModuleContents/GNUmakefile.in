
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = FModuleContents
BUNDLE_EXTENSION = .finder

FModuleContents_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

FModuleContents_OBJC_FILES = FModuleContents.m 

FModuleContents_PRINCIPAL_CLASS = FModuleContents

FModuleContents_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/FModuleContents.gorm

include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

include GNUmakefile.postamble

