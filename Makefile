ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
PACKAGE_VERSION = 1.0
PACKAGE_NAME = hoangha_aimbot
BUNDLE_ID = hoangha.app

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = HoangHaAimbot
HoangHaAimbot_FILES = app/main.m \
    app/AppDelegate.m \
    app/AOTFloatingMenu.m \
    app/AOTBoneManager.m \
    app/AOTRenderer.m \
    app/AOTMemoryManager.m \
    app/AOTMatrix4x4.m \
    app/AOTVector3.m \
    app/AOTPlayerStructure.m \
    app/AOTSettingsManager.m

HoangHaAimbot_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation
HoangHaAimbot_LDFLAGS = -lobjc -framework Foundation
HoangHaAimbot_CFLAGS = -fobjc-arc
HoangHaAimbot_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "killall -9 SpringBoard"
