ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
PACKAGE_VERSION = 1.0
PACKAGE_NAME = hoangha_aimbot
BUNDLE_ID = hoangha.app

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HoangHaAimbot
HoangHaAimbot_FILES = app/Tweak.xm \
    app/AOTFloatingMenu.m \
    app/AOTBoneManager.m \
    app/AOTRenderer.m \
    app/AOTMemoryManager.m \
    app/AOTMatrix4x4.m \
    app/AOTVector3.m \
    app/AOTPlayerStructure.m \
    app/AOTSettingsManager.m

HoangHaAimbot_FRAMEWORKS = UIKit CoreGraphics QuartzCore
HoangHaAimbot_LDFLAGS = -lobjc -framework Foundation
HoangHaAimbot_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
