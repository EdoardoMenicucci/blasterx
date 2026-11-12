#pragma once

#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVector>

// One mixer element as the card reports it. Values hold one entry per
// channel: 0/1 for switches, the raw integer for levels, and the item index
// for enumerations.
struct Control {
    enum Type { Boolean, Integer, Enumerated };

    QString name;
    Type type = Integer;
    int min = 0;
    int max = 1;
    int count = 1;
    QStringList items;
    QVector<int> values;
    bool writable = true;
};

// The card behind an interface, so the backend can be tested without the
// hardware. AlsaDevice is the real one.
class ControlDevice : public QObject {
    Q_OBJECT

public:
    using QObject::QObject;

    virtual bool isOpen() const = 0;
    virtual QString name() const = 0;
    virtual QString error() const = 0;
    // Every control with its current values, read fresh from the card.
    virtual QList<Control> controls() = 0;
    virtual bool write(const QString &name, const QVector<int> &values) = 0;

signals:
    // Something on the card changed, by this app or by anything else.
    void changed();
};
