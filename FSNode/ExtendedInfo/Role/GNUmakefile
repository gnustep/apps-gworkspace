
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = Role
BUNDLE_EXTENSION = .extinfo

#Role_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
Role_OBJC_FILES = ExtInfoRole.m 

Role_PRINCIPAL_CLASS = ExtInfoRole

ADDITIONAL_GUI_LIBS += -lFSNode

Role_LANGUAGES = \
	English \
	Italian \
	German \
	French \

#Role_LOCALIZED_RESOURCE_FILES = Localizable.strings

Role_RESOURCE_FILES = \
	Resources/Localizable.strings \
	Resources/*.lproj \


-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

