VERSION := $(shell /bin/cat ../VERSION)
PREFIX=/usr/local
SWIFT_BUILD_FLAGS=--configuration release

.PHONY: clean build install package

init:
	@swift package generate-xcodeproj

build:
	@swift build --disable-sandbox $(SWIFT_BUILD_FLAGS)

clean:
	rm -rf .build

install: build
	$(call install_files,$(PREFIX)) 

uninstall:
	rm "$(PREFIX)/bin/lucid"

package: build
	$(call install_files,./build/package/lucid)
	cd ./build/package/ && zip -r ../../lucid-$(VERSION).zip ./lucid

define install_files
	install -d $(1)/bin
	install -C .build/release/lucid $(1)/bin/lucid
endef
