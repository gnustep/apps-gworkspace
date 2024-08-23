
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = FModuleName
BUNDLE_EXTENSION = .finder

FModuleName_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

FModuleName_OBJC_FILES = FModuleName.m 

FModuleName_PRINCIPAL_CLASS = FModuleName

FModuleName_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/FModuleName.gorm

include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

include GNUmakefile.postamble

