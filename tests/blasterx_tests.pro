QT += core gui quick quickcontrols2 testlib
CONFIG += c++17 testcase
TARGET = blasterx_tests
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += ../src/controldevice.h ../src/backend.h ../src/theme.h ../src/translator.h
SOURCES += blasterx_tests.cpp ../src/backend.cpp ../src/theme.cpp ../src/translator.cpp
DEFINES += SRCDIR=\\\"$$PWD\\\"
