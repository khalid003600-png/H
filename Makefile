# WolFox Unified Theos Project
# Shared source; package output is generated for Rootful and Rootless.

THEOS ?= /home/ubuntu/theos
SDKROOT ?= $(THEOS)/sdks/iPhoneOS16.5.sdk
TARGET := iphone:latest:15.0
ARCHS := arm64
WOLFOX_MIN_RUNTIME ?= 15.8
WOLFOX_MAX_RUNTIME ?= 26.5
WOLFOX_BUNDLE_ID ?= sa.gov.moia.mosques-2

export THEOS SDKROOT

.PHONY: all package rootful rootless clean test verify check-ios

all: package

check-ios:
	@test "$(ARCHS)" = "arm64" || (echo "ARCHS must be arm64"; exit 1)
	@echo "Runtime policy: iOS $(WOLFOX_MIN_RUNTIME)+"
	@echo "Source compatibility target: iOS $(WOLFOX_MIN_RUNTIME)-$(WOLFOX_MAX_RUNTIME)"
	@echo "Deployment target used by Clang: 15.0"
	@echo "Bundle filter: $(WOLFOX_BUNDLE_ID)"

package: check-ios
	@THEOS="$(THEOS)" SDKROOT="$(SDKROOT)" MIN_IOS=15.0 REQUIRED_SDK_VERSION=16.5 WOLFOX_ARCHS=arm64 WOLFOX_TARGET_BUNDLE_IDS="$(WOLFOX_BUNDLE_ID)" WOLFOX_REQUIRE_SIGNING=1 WOLFOX_HARDENING=1 ./build_v1_deb.sh

rootful: package
rootless: package

test:
	@./run_all_linux_tests.sh

verify:
	@./test_build_compatibility_static.sh

clean:
	@rm -rf .wolfox-build WolFox.dylib WolFox_v*_Rootful.deb WolFox_v*_Rootless.deb
