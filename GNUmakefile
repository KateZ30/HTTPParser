# GNUmakefile for Swift variant

PACKAGE_DIR=.
debug=on

include $(PACKAGE_DIR)/xcconfig/config.make

ifeq ($(HAVE_SPM),yes)

all :
	$(SWIFT_BUILD_TOOL)

clean :
	$(SWIFT_CLEAN_TOOL)

distclean : clean
	rm -rf .build

tests : all
	$(SWIFT_TEST_TOOL)

else

all :
	@$(MAKE) -C Sources/HTTPParser all

clean :
	rm -rf .build

distclean : clean

endif

