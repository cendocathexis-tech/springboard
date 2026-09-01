TARGET := iphone:clang:16.5:16.0
THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SBWidgetDesignerPrefs

SBWidgetDesignerPrefs_FILES = SBWDRootListController.m
SBWidgetDesignerPrefs_INSTALL_PATH = /Library/PreferenceBundles
SBWidgetDesignerPrefs_FRAMEWORKS = UIKit
SBWidgetDesignerPrefs_PRIVATE_FRAMEWORKS = Preferences
SBWidgetDesignerPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SBWidgetDesigner.plist$(ECHO_END)
