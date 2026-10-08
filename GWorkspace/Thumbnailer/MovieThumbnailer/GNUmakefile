PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = MovieThumbnailer
BUNDLE_EXTENSION = .thumb
MovieThumbnailer_OBJC_FILES = MovieThumbnailer.m
MovieThumbnailer_PRINCIPAL_CLASS = MovieThumbnailer

ADDITIONAL_OBJCFLAGS += -Wall
ADDITIONAL_INCLUDE_DIRS += -I../
LIBRARIES_DEPEND_UPON += $(GUI_LIBS) $(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)

include $(GNUSTEP_MAKEFILES)/bundle.make
