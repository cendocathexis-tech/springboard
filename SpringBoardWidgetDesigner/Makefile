TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard
THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SBWidgetDesigner

SBWidgetDesigner_FILES = Tweak.xm SBWDManager.m SBWDWidgetHost.m SBWDEditorPresenter.m
SBWidgetDesigner_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-unused-function
SBWidgetDesigner_FRAMEWORKS = UIKit WebKit Foundation CoreText CoreGraphics
SBWidgetDesigner_LDFLAGS = -lsubstrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
