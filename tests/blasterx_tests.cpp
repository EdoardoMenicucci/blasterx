#include <QDir>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

#include "backend.h"
#include "theme.h"
#include "translator.h"

// A card in memory, shaped like the AE-5's controls.
class FakeDevice : public ControlDevice {
public:
    QList<Control> state;
    QStringList refuse;
    int writes = 0;

    FakeDevice() {
        state << Control{"Output Select", Control::Enumerated, 0, 1, 1, {"Speakers", "Headphone"}, {1}, true}
              << Control{"Front Playback Volume", Control::Integer, 0, 99, 2, {}, {90, 90}, true}
              << Control{"FX: Crystalizer Playback Switch", Control::Boolean, 0, 1, 1, {}, {1}, true}
              << Control{"Headphone Jack", Control::Boolean, 0, 1, 1, {}, {1}, false};
        for (int i = 0; i < 3; ++i)
            state << Control{QString("EQ Band%1 Playback Volume").arg(i), Control::Integer, 0, 48, 1, {}, {24}, true};
        state << Control{"FX: Equalizer Preset Switch", Control::Enumerated, 0, 1, 1, {"Flat", "Rock"}, {0}, true};
    }

    bool isOpen() const override { return true; }
    QString name() const override { return "Sound BlasterX AE-5"; }
    QString error() const override { return "Input/output error"; }
    QList<Control> controls() override { return state; }
    bool write(const QString &name, const QVector<int> &values) override {
        if (refuse.contains(name))
            return false;
        ++writes;
        for (auto &c : state)
            if (c.name == name) {
                c.values = values;
                // Like the driver: a preset moves the bands.
                if (name == "FX: Equalizer Preset Switch" && values.value(0) == 1)
                    for (auto &band : state)
                        if (band.name.startsWith("EQ Band"))
                            band.values = {30};
            }
        return true;
    }
    int value(const QString &name) const {
        for (const auto &c : state)
            if (c.name == name)
                return c.values.value(0);
        return -1;
    }
};

class BlasterxTests : public QObject {
    Q_OBJECT

private slots:
    void exposesValuesAndInfo() {
        FakeDevice device;
        QTemporaryDir dir;
        Backend backend(&device, dir.path());
        QVERIFY(backend.available());
        QCOMPARE(backend.values().value("Output Select").toInt(), 1);
        QCOMPARE(backend.values().value("FX: Crystalizer Playback Switch").toBool(), true);
        QCOMPARE(backend.info().value("Front Playback Volume").toMap().value("max").toInt(), 99);
        QCOMPARE(backend.info().value("Output Select").toMap().value("items").toStringList(),
                 QStringList({"Speakers", "Headphone"}));
    }

    void setWritesEveryChannelAndClamps() {
        FakeDevice device;
        QTemporaryDir dir;
        Backend backend(&device, dir.path());
        QVERIFY(backend.set("Front Playback Volume", 150));
        QCOMPARE(device.state[1].values, QVector<int>({99, 99}));
        QCOMPARE(backend.values().value("Front Playback Volume").toInt(), 99);
    }

    void unchangedValueSkipsTheCard() {
        FakeDevice device;
        QTemporaryDir dir;
        Backend backend(&device, dir.path());
        QVERIFY(backend.set("Output Select", 1));
        QCOMPARE(device.writes, 0);
        QVERIFY(!backend.canUndo());
    }

    void readOnlyAndFailedWritesReport() {
        FakeDevice device;
        device.refuse << "Output Select";
        QTemporaryDir dir;
        Backend backend(&device, dir.path());
        QSignalSpy messages(&backend, &Backend::message);
        QVERIFY(!backend.set("Headphone Jack", false));
        QVERIFY(!backend.set("Output Select", 0));
        QCOMPARE(messages.count(), 2);
        QVERIFY(messages.last().at(1).toBool());
        QCOMPARE(backend.values().value("Output Select").toInt(), 1);
    }

    void undoAndRedo() {
        FakeDevice device;
        QTemporaryDir dir;
        Backend backend(&device, dir.path());
        backend.toggle("FX: Crystalizer Playback Switch");
        QCOMPARE(device.value("FX: Crystalizer Playback Switch"), 0);
        backend.undo();
        QCOMPARE(device.value("FX: Crystalizer Playback Switch"), 1);
        QVERIFY(backend.canRedo());
        backend.redo();
        QCOMPARE(device.value("FX: Crystalizer Playback Switch"), 0);
    }

    void sliderDragIsOneUndoStep() {
        FakeDevice device;
        QTemporaryDir dir;
        Backend backend(&device, dir.path());
        for (int v = 80; v >= 60; v -= 5)
            backend.set("Front Playback Volume", v);
        backend.undo();
        QCOMPARE(device.value("Front Playback Volume"), 90);
        QVERIFY(!backend.canUndo());
    }

    void setManyIsOneUndoStep() {
        FakeDevice device;
        QTemporaryDir dir;
        Backend backend(&device, dir.path());
        QVERIFY(backend.setMany({{"EQ Band0 Playback Volume", 10}, {"EQ Band1 Playback Volume", 40}}));
        QCOMPARE(device.value("EQ Band1 Playback Volume"), 40);
        backend.undo();
        QCOMPARE(device.value("EQ Band0 Playback Volume"), 24);
        QCOMPARE(device.value("EQ Band1 Playback Volume"), 24);
    }

    void driverSideEffectsShowUp() {
        FakeDevice device;
        QTemporaryDir dir;
        Backend backend(&device, dir.path());
        backend.set("FX: Equalizer Preset Switch", 1);
        QTRY_COMPARE(backend.values().value("EQ Band2 Playback Volume").toInt(), 30);
    }

    void parsesCommandLineValues() {
        FakeDevice device;
        QTemporaryDir dir;
        Backend backend(&device, dir.path());
        int v = -1;
        QVERIFY(backend.parseValue("Output Select", "headphone", &v));
        QCOMPARE(v, 1);
        QVERIFY(backend.parseValue("Output Select", "spea", &v));
        QCOMPARE(v, 0);
        QVERIFY(backend.parseValue("FX: Crystalizer Playback Switch", "off", &v));
        QCOMPARE(v, 0);
        QVERIFY(backend.parseValue("Front Playback Volume", "42", &v));
        QCOMPARE(v, 42);
        QVERIFY(!backend.parseValue("Front Playback Volume", "120", &v));
        QVERIFY(!backend.parseValue("Output Select", "line", &v));
    }

    void profilesRoundTrip() {
        FakeDevice device;
        QTemporaryDir dir;
        Backend backend(&device, dir.path() + "/profiles");
        QVERIFY(backend.saveProfile("Music"));
        QCOMPARE(backend.profiles(), QStringList{"Music"});
        QVERIFY(backend.profileExists("Music"));

        backend.set("Front Playback Volume", 10);
        backend.set("Output Select", 0);
        backend.set("FX: Equalizer Preset Switch", 1);
        QVERIFY(backend.applyProfile("Music"));
        QCOMPARE(device.value("Front Playback Volume"), 90);
        QCOMPARE(device.value("Output Select"), 1);
        // The preset is restored before the bands, so the bands win.
        QCOMPARE(device.value("FX: Equalizer Preset Switch"), 0);
        QCOMPARE(device.value("EQ Band0 Playback Volume"), 24);

        // The whole profile is one undo step.
        backend.undo();
        QCOMPARE(device.value("Front Playback Volume"), 10);
        QCOMPARE(device.value("Output Select"), 0);

        QVERIFY(backend.deleteProfile("Music"));
        QVERIFY(backend.profiles().isEmpty());
    }

    void profilesLeaveOutReadOnlyControls() {
        FakeDevice device;
        QTemporaryDir dir;
        Backend backend(&device, dir.path());
        const QJsonObject controls = backend.snapshot().value("controls").toObject();
        QVERIFY(controls.contains("Output Select"));
        QVERIFY(!controls.contains("Headphone Jack"));
    }

    void rejectsUnsafeProfileNames() {
        FakeDevice device;
        QTemporaryDir dir;
        Backend backend(&device, dir.path());
        QVERIFY(backend.isValidProfileName("Games 2"));
        QVERIFY(!backend.isValidProfileName(""));
        QVERIFY(!backend.isValidProfileName("../evil"));
        QVERIFY(!backend.isValidProfileName(".hidden"));
        QVERIFY(!backend.isValidProfileName(" padded"));
        QVERIFY(!backend.saveProfile("a/b"));
    }

    void themeFallsBack() {
        QTemporaryDir dir;
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#FFD60A"));
        QCOMPARE(theme.accentForeground(), QString("black"));
    }

    void themeReadsAccent() {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("theme");
        write(dir.path() + "/theme/colors.toml", "accent = \"#112233\"\n");
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#112233"));
        QCOMPARE(theme.accentForeground(), QString("white"));
    }

    void themeFollowsHyprlandRounding() {
        QTemporaryDir dir;
        const QString response = dir.filePath("response.json"), command = dir.filePath("hyprctl");
        write(command, "#!/bin/sh\ncat '" + response.toUtf8() + "'\n");
        QVERIFY(QFile::setPermissions(command, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        write(response, "{\"int\":0}");

        Theme theme(dir.path(), nullptr, command);
        QCOMPARE(theme.radius(), 0);
        write(response, "{\"int\":6}");
        QTRY_COMPARE(theme.radius(), 6);
    }

    void translatorFallsBackToEnglish() {
        QTemporaryDir dir;
        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.language(), QString("en"));
        QVERIFY(translator.translate("Main", "Save").isNull());
    }

    void translatorFollowsTheLanguageFile() {
        QTemporaryDir dir;
        write(dir.path() + "/language", "pt-BR\n");
        write(dir.path() + "/pt.json", R"({"Save": "Guardar", "Open": "Abrir"})");
        write(dir.path() + "/pt-BR.json", R"({"Save": "Salvar"})");
        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.translate("Main", "Save"), QString("Salvar"));
        QCOMPARE(translator.translate("Main", "Open"), QString("Abrir"));
        QVERIFY(translator.translate("Main", "Quit").isNull());
    }

    void italianCatalogLoads() {
        QTemporaryDir dir;
        write(dir.path() + "/language", "it\n");
        Translator translator(dir.path() + "/language", QString(SRCDIR) + "/../src/i18n");
        QCOMPARE(translator.translate("Main", "Equalizer"), QString("Equalizzatore"));
        QCOMPARE(translator.translate("Backend", "Applied %1, but %n controls could not be set.", nullptr, 1),
                 QString("Applicato %1, ma %n controllo non è stato impostato."));
    }

private:
    static void write(const QString &path, const QByteArray &contents) {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(contents);
    }
};

QTEST_MAIN(BlasterxTests)
#include "blasterx_tests.moc"
