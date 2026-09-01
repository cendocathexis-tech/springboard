TARGET := iphone:clang:16.5:16.0
INSTALL_TARGET_PROCESSES = SpringBoard
THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Sunlight

Sunlight_FILES = Tweak.xm SBWDManager.m SBWDWidgetHost.m SBWDEditorPresenter.m
Sunlight_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-unused-function
Sunlight_FRAMEWORKS = UIKit WebKit Foundation CoreText CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
