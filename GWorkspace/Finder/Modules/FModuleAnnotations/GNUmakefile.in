
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = FModuleAnnotations
BUNDLE_EXTENSION = .finder

FModuleAnnotations_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

FModuleAnnotations_OBJC_FILES = FModuleAnnotations.m 

FModuleAnnotations_PRINCIPAL_CLASS = FModuleAnnotations

FModuleAnnotations_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/FModuleAnnotations.gorm

include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

include GNUmakefile.postamble

