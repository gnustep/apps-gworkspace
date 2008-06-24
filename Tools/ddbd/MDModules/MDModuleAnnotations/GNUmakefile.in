# Install into the system root by default
GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
RPM_DISABLE_RELOCATABLE=YES

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = MDModuleAnnotations
BUNDLE_EXTENSION = .mdm

OBJCFLAGS += -Wall

MDModuleAnnotations_OBJC_FILES = MDModuleAnnotations.m 

MDModuleAnnotations_PRINCIPAL_CLASS = MDModuleAnnotations

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

