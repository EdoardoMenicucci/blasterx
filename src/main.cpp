// blasterx — a control panel for Creative Sound Blaster cards on the CA0132
// codec (AE-5, AE-5 Plus, AE-7, Z, ZxR), on top of the ALSA mixer.

#include <QCoreApplication>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QUrl>

#include "alsadevice.h"
#include "backend.h"
#include "cli.h"
#include "theme.h"
#include "translator.h"

int main(int argc, char *argv[]) {
    QStringList arguments;
    for (int i = 0; i < argc; ++i)
        arguments << QString::fromLocal8Bit(argv[i]);

    // Commands run without a display, so they work over SSH and from scripts.
    if (isCliCommand(arguments)) {
        QCoreApplication app(argc, argv);
        app.setApplicationName("blasterx");
        return runCli(arguments);
    }
    if (arguments.size() > 1 && arguments[1] != "open") {
        fprintf(stderr, "Unknown command %s. Try `blasterx help`.\n", argv[1]);
        return 1;
    }

    QGuiApplication app(argc, argv);
    app.setApplicationName("blasterx");
    app.setApplicationVersion("0.1.0");

    // Matches the window to blasterx.desktop, so the compositor (Wayland
    // app_id) and the launcher pick up the installed icon.
    app.setDesktopFileName("blasterx");
    app.setWindowIcon(QIcon::fromTheme("blasterx"));

    QQuickStyle::setStyle("Material");

    // Installed before anything is translated, and every qsTr() binding is
    // re-evaluated when the Omarchy language changes.
    Translator translator;
    app.installTranslator(&translator);

    Theme theme;
    AlsaDevice device;
    Backend backend(&device);

    QQmlApplicationEngine engine;
    QObject::connect(&translator, &Translator::changed, &engine, &QQmlEngine::retranslate);
    engine.rootContext()->setContextProperty("translator", &translator);
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("backend", &backend);
    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;

    return app.exec();
}
