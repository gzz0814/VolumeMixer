ifdef SIMULATOR
export TARGET = simulator:clang:latest:8.0
else
export TARGET = iphone:clang:latest:7.0
	ifeq ($(debug),0)
		export ARCHS = armv7 arm64 arm64e
	else
		export ARCHS = arm64 arm64e
	endif
endif

# Build as a rootless package so the tweak/prefs/CC install under the jailbreak
# root prefix (/var/jb) and get picked up by rootless / roothide (RootHide)
# injectors and PreferenceLoader. A rootful (/Library) build is invisible to
# these jailbreaks, which is why the tweak never loaded on roothide.
THEOS_PACKAGE_SCHEME = rootless

INSTALL_TARGET_PROCESSES = SpringBoard

TWEAK_NAME = VolumeMixer

VolumeMixer_FILES = Tweak.xm VMHookInfo.mm VMHookAudioUnit.mm 
VolumeMixer_CFLAGS = -fobjc-arc
VolumeMixer_LIBRARIES += substrate
VolumeMixer_LOGOSFLAGS += -c generator=MobileSubstrate
# Private audio / SpringBoard symbols are resolved at load time in-process.
VolumeMixer_LDFLAGS = -undefined dynamic_lookup

VolumeMixer_FILES += TweakSB.xm VMHUDView.m VMHUDWindow.m VMHUDRootViewController.m VMLAListener.m VMLAVolumeDownListener.m VMLAVolumeUpListener.m
ifdef SIMULATOR
VolumeMixer_FILES += sim.x
endif

BUNDLE_NAME = volumemixer CCVolumeMixer

volumemixer_FILES = volumemixerpref/VMPrefRootListController.m volumemixerpref/BDInfoListController.m volumemixerpref/VMLicenseViewController.m volumemixerpref/VMAuthorListController.m volumemixerpref/VMAppListController.m
volumemixer_INSTALL_PATH = /Library/PreferenceBundles
volumemixer_FRAMEWORKS = UIKit
# Preferences is a private framework whose stub is not in the iOS SDK; the
# PS* classes are resolved at runtime by PreferenceLoader, so link dynamically.
volumemixer_LDFLAGS = -undefined dynamic_lookup
volumemixer_CFLAGS = -fobjc-arc
volumemixer_RESOURCE_DIRS = volumemixerpref/Resources

CCVolumeMixer_BUNDLE_EXTENSION = bundle
CCVolumeMixer_FILES = ccvolumemixer/CCVolumeMixer.m
CCVolumeMixer_CFLAGS = -fobjc-arc
# ControlCenterUIKit stub is not in the SDK; CCUIToggleModule resolves at runtime.
CCVolumeMixer_LDFLAGS = -undefined dynamic_lookup
CCVolumeMixer_INSTALL_PATH = /Library/ControlCenter/Bundles/
CCVolumeMixer_RESOURCE_DIRS = ccvolumemixer/Resources

# Companion LSUIElement app that owns the "volumemixer://" URL scheme so the
# Shortcuts "Open URL" action can resolve it (see launcher/main.m).
APPLICATION_NAME = VolumeMixerLauncher
VolumeMixerLauncher_FILES = launcher/main.m
VolumeMixerLauncher_CFLAGS = -fobjc-arc
VolumeMixerLauncher_FRAMEWORKS = UIKit Foundation
VolumeMixerLauncher_INSTALL_PATH = /Applications
# Theos has no $(TARGET)_INFOPLIST variable: an application's Info.plist must be
# supplied as a bundle resource, and Theos relocates it into the .app root. This
# is what registers the "volumemixer://" scheme with LaunchServices.
VolumeMixerLauncher_RESOURCE_FILES = launcher/Info.plist

export ADDITIONAL_CFLAGS += -Wno-error -Wno-error=unused-variable -Wno-error=unused-function -Wno-error=unused-value -Wno-error=unused-but-set-variable -include Prefix.pch

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
include $(THEOS_MAKE_PATH)/application.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp volumemixerpref/entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/volumemixer.plist$(ECHO_END)
