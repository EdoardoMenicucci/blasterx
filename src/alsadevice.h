#pragma once

#include "controldevice.h"

#include <QHash>
#include <QList>

struct _snd_ctl;
class QSocketNotifier;

// Talks to the Sound Blaster's control interface through alsa-lib. The card
// is found by its Creative codec rather than a fixed index, because card
// numbers move when USB audio devices come and go.
class AlsaDevice : public ControlDevice {
    Q_OBJECT

public:
    // An explicit ALSA name ("hw:2") skips the search; BLASTERX_CARD does too.
    explicit AlsaDevice(const QString &card = {}, QObject *parent = nullptr);
    ~AlsaDevice() override;

    bool isOpen() const override { return m_ctl != nullptr; }
    QString name() const override { return m_name; }
    QString error() const override { return m_error; }
    QList<Control> controls() override;
    bool write(const QString &name, const QVector<int> &values) override;

private:
    bool open(const QString &card);
    void watch();
    void drainEvents();

    _snd_ctl *m_ctl = nullptr;
    QString m_name;
    QString m_error;
    QHash<QString, unsigned int> m_numids;
    QList<QSocketNotifier *> m_notifiers;
};
