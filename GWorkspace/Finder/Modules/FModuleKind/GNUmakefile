
include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

BUNDLE_NAME = FModuleKind
BUNDLE_EXTENSION = .finder

FModuleKind_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

FModuleKind_OBJC_FILES = FModuleKind.m 

FModuleKind_PRINCIPAL_CLASS = FModuleKind

FModuleKind_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/FModuleKind.gorm

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

