include $(GNUSTEP_MAKEFILES)/common.make

ifneq ($(FOUNDATION_LIB), apple)
  SUBPROJECTS = \
       findfile \
       thumbnailer \
       wopen 
else
  SUBPROJECTS = \
       findfile 
endif

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.postamble

