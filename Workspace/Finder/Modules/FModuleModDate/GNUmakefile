
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = FModuleModDate
BUNDLE_EXTENSION = .finder

FModuleModDate_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

FModuleModDate_OBJC_FILES = FModuleModDate.m 

FModuleModDate_PRINCIPAL_CLASS = FModuleModDate

FModuleModDate_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/FModuleModDate.gorm

include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

include GNUmakefile.postamble

