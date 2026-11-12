QT += core gui qml quick quickcontrols2

CONFIG += c++17 release link_pkgconfig
PKGCONFIG += alsa
TARGET = blasterx
TEMPLATE = app

HEADERS += \
    src/alsadevice.h \
    src/backend.h \
    src/cli.h \
    src/controldevice.h \
    src/theme.h \
    src/translator.h

SOURCES += \
    src/main.cpp \
    src/alsadevice.cpp \
    src/backend.cpp \
    src/cli.cpp \
    src/theme.cpp \
    src/translator.cpp

RESOURCES += src/resources.qrc
