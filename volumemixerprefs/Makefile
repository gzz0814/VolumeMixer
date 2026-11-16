ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = volumemixer

volumemixer_FILES = VMPrefRootListController.m
volumemixer_INSTALL_PATH = /Library/PreferenceBundles
volumemixer_FRAMEWORKS = UIKit
volumemixer_PRIVATE_FRAMEWORKS = Preferences
volumemixer_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
