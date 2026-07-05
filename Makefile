ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
PACKAGE_VERSION = 1.0

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
HoangHaAimbot_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 com.dts.freefireth"
