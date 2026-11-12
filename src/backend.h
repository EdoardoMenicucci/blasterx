#pragma once

#include "controldevice.h"

#include <QElapsedTimer>
#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantMap>

// The card's state as QML sees it. Every control is keyed by its ALSA name;
// `values` holds the first channel of each (a bool for switches, an int for
// levels and choices) and `info` describes its range and choices. Writes go
// straight to the card, and the whole state is read back afterwards because
// the driver changes related controls on its own (an EQ preset moves the
// bands).
class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY deviceChanged)
    Q_PROPERTY(QString deviceName READ deviceName NOTIFY deviceChanged)
    Q_PROPERTY(QString deviceError READ deviceError NOTIFY deviceChanged)
    Q_PROPERTY(QVariantMap values READ values NOTIFY valuesChanged)
    Q_PROPERTY(QVariantMap info READ info NOTIFY infoChanged)
    Q_PROPERTY(QStringList names READ names NOTIFY infoChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY historyChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY historyChanged)
    Q_PROPERTY(QStringList profiles READ profiles NOTIFY profilesChanged)
    Q_PROPERTY(QString profileDirectory READ profileDirectory CONSTANT)

public:
    explicit Backend(ControlDevice *device, const QString &profileDirectory = {}, QObject *parent = nullptr);

    bool available() const { return m_device && m_device->isOpen(); }
    QString deviceName() const { return m_device ? m_device->name() : QString(); }
    QString deviceError() const { return m_device ? m_device->error() : QString(); }
    QVariantMap values() const { return m_values; }
    QVariantMap info() const { return m_info; }
    QStringList names() const { return m_order; }
    bool canUndo() const { return !m_undo.isEmpty(); }
    bool canRedo() const { return !m_redo.isEmpty(); }
    QStringList profiles() const { return m_profiles; }
    QString profileDirectory() const { return m_profileDirectory; }

    QList<Control> controls() const;
    Control control(const QString &name) const { return m_controls.value(name); }

    Q_INVOKABLE void refresh();
    // A bool or number for every channel; values outside the range are clamped.
    Q_INVOKABLE bool set(const QString &name, const QVariant &value);
    Q_INVOKABLE bool toggle(const QString &name);
    // Several controls at once, undone as one step (resetting the EQ bands).
    Q_INVOKABLE bool setMany(const QVariantMap &changes);
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();

    Q_INVOKABLE bool isValidProfileName(const QString &name) const;
    Q_INVOKABLE bool profileExists(const QString &name) const;
    Q_INVOKABLE bool saveProfile(const QString &name);
    Q_INVOKABLE bool applyProfile(const QString &name);
    Q_INVOKABLE bool deleteProfile(const QString &name);

    // "on", "Headphone" (or a unique prefix of it), or a plain number, as typed
    // on the command line.
    bool parseValue(const QString &name, const QString &text, int *out) const;
    QJsonObject snapshot() const;

signals:
    void deviceChanged();
    void valuesChanged();
    void infoChanged();
    void historyChanged();
    void profilesChanged();
    // A short message for the status line: what happened or what went wrong.
    void message(const QString &text, bool error);

private:
    struct Edit {
        QString name;
        QVector<int> before;
        QVector<int> after;
    };
    struct Step {
        QList<Edit> edits;
        qint64 at = 0;
    };

    bool writeValues(const QString &name, const QVector<int> &values);
    void record(const QList<Edit> &edits);
    void replay(QList<Step> &from, QList<Step> &to, bool forward);
    QString profilePath(const QString &name) const;
    void loadProfiles();
    void fail(const QString &text);

    ControlDevice *m_device;
    QString m_profileDirectory;
    QHash<QString, Control> m_controls;
    QStringList m_order;
    QVariantMap m_values;
    QVariantMap m_info;
    QList<Step> m_undo, m_redo;
    QElapsedTimer m_clock;
    QStringList m_profiles;
    QTimer m_refresh;
};
