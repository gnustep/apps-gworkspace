
include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

BUNDLE_NAME = Stemmer
Stemmer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

Stemmer_PRINCIPAL_CLASS = Stemmer

Stemmer_RESOURCE_FILES = Resources/*

Stemmer_OBJC_FILES = Stemmer.m

Stemmer_C_FILES = \
libstemmer/libstemmer.c \
runtime/api.c \
runtime/utilities.c \
src_c/stem_ISO_8859_1_danish.c \
src_c/stem_ISO_8859_1_dutch.c \
src_c/stem_ISO_8859_1_english.c \
src_c/stem_ISO_8859_1_finnish.c \
src_c/stem_ISO_8859_1_french.c \
src_c/stem_ISO_8859_1_german.c \
src_c/stem_ISO_8859_1_italian.c \
src_c/stem_ISO_8859_1_norwegian.c \
src_c/stem_ISO_8859_1_porter.c \
src_c/stem_ISO_8859_1_portuguese.c \
src_c/stem_ISO_8859_1_spanish.c \
src_c/stem_ISO_8859_1_swedish.c \
src_c/stem_KOI8_R_russian.c \
src_c/stem_UTF_8_danish.c \
src_c/stem_UTF_8_dutch.c \
src_c/stem_UTF_8_english.c \
src_c/stem_UTF_8_finnish.c \
src_c/stem_UTF_8_french.c \
src_c/stem_UTF_8_german.c \
src_c/stem_UTF_8_italian.c \
src_c/stem_UTF_8_norwegian.c \
src_c/stem_UTF_8_porter.c \
src_c/stem_UTF_8_portuguese.c \
src_c/stem_UTF_8_russian.c \
src_c/stem_UTF_8_spanish.c \
src_c/stem_UTF_8_swedish.c 

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.preamble
-include GNUmakefile.postamble

