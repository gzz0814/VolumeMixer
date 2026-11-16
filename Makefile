ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VolumeMixer

VolumeMixer_FILES = \
	src/Tweak.x \
	src/VolumeControl.m \
	src/VMHUDWindow.m \
	src/VMHUDRootViewController.m \
	src/VMHUDView.m \
	src/VolumeMixerLAListener.m \
	src/VMIPCCenter.m \
	src/UIImage+VMIcon.m

VolumeMixer_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
VolumeMixer_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore AVFoundation AudioToolbox
VolumeMixer_LIBRARIES = substrate
VolumeMixer_EXTRA_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += volumemixerprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
