#include "cli.h"

#include "alsadevice.h"
#include "backend.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTextStream>

namespace {

QTextStream &out() { static QTextStream s(stdout); return s; }
QTextStream &err() { static QTextStream s(stderr); return s; }

const char *kUsage =
    "Usage: blasterx [open]                   open the window\n"
    "       blasterx list [--json]            every control and its value\n"
    "       blasterx get <control> [--json]   one control\n"
    "       blasterx set <control> <value>    on/off, a number, or a choice name\n"
    "       blasterx profile list [--json]\n"
    "       blasterx profile save <name>      store the current settings\n"
    "       blasterx profile apply <name>\n"
    "       blasterx profile delete <name>\n";

QString describe(const Control &c) {
    QStringList shown;
    for (int v : c.values) {
        if (c.type == Control::Boolean) shown << (v ? "on" : "off");
        else if (c.type == Control::Enumerated) shown << c.items.value(v, QString::number(v));
        else shown << QString::number(v);
    }
    shown.removeDuplicates();
    QString range;
    if (c.type == Control::Integer) range = QString("  [%1..%2]").arg(c.min).arg(c.max);
    else if (c.type == Control::Enumerated) range = "  [" + c.items.join(" | ") + "]";
    return QString("%1 = %2%3%4").arg(c.name, shown.join(","), range, c.writable ? "" : "  (read-only)");
}

QJsonObject toJson(const Control &c) {
    QJsonArray values;
    for (int v : c.values) values << v;
    QJsonObject o{{"name", c.name}, {"values", values}, {"writable", c.writable}};
    switch (c.type) {
    case Control::Boolean: o["type"] = "boolean"; break;
    case Control::Integer: o["type"] = "integer"; o["min"] = c.min; o["max"] = c.max; break;
    case Control::Enumerated: o["type"] = "enum"; o["items"] = QJsonArray::fromStringList(c.items); break;
    }
    return o;
}

void print(const QJsonValue &v) {
    out() << (v.isArray() ? QJsonDocument(v.toArray()) : QJsonDocument(v.toObject())).toJson(QJsonDocument::Indented);
}

} // namespace

bool isCliCommand(const QStringList &arguments) {
    static const QStringList commands{"list", "get", "set", "profile", "help", "--help", "-h"};
    return arguments.size() > 1 && commands.contains(arguments.at(1));
}

int runCli(const QStringList &arguments) {
    QStringList args = arguments.mid(1);
    const bool json = args.removeAll("--json") > 0;
    const QString command = args.value(0);

    if (command == "help" || command == "--help" || command == "-h") {
        out() << kUsage;
        return 0;
    }

    AlsaDevice device;
    if (!device.isOpen()) {
        err() << device.error() << "\n";
        return 1;
    }
    Backend backend(&device);
    QString lastError;
    QObject::connect(&backend, &Backend::message, [&](const QString &text, bool error) {
        if (error) lastError = text;
    });
    auto failWith = [&](const QString &text) { err() << text << "\n"; return 1; };

    if (command == "list") {
        if (json) {
            QJsonArray all;
            for (const auto &c : backend.controls()) all << toJson(c);
            print(all);
        } else {
            out() << device.name() << "\n";
            for (const auto &c : backend.controls()) out() << "  " << describe(c) << "\n";
        }
        return 0;
    }

    if (command == "get" && args.size() == 2) {
        if (!backend.names().contains(args[1]))
            return failWith(QString("No control named \"%1\". Run `blasterx list`.").arg(args[1]));
        const Control c = backend.control(args[1]);
        if (json) print(toJson(c));
        else out() << describe(c) << "\n";
        return 0;
    }

    if (command == "set" && args.size() == 3) {
        if (!backend.names().contains(args[1]))
            return failWith(QString("No control named \"%1\". Run `blasterx list`.").arg(args[1]));
        int value = 0;
        if (!backend.parseValue(args[1], args[2], &value))
            return failWith(QString("\"%1\" is not a valid value for %2: %3")
                                .arg(args[2], args[1], describe(backend.control(args[1]))));
        if (!backend.set(args[1], value))
            return failWith(lastError);
        backend.refresh();
        if (json) print(toJson(backend.control(args[1])));
        else out() << describe(backend.control(args[1])) << "\n";
        return 0;
    }

    if (command == "profile") {
        const QString action = args.value(1), name = args.value(2);
        if (action == "list" && args.size() == 2) {
            if (json) print(QJsonArray::fromStringList(backend.profiles()));
            else for (const auto &p : backend.profiles()) out() << p << "\n";
            return 0;
        }
        if (args.size() == 3) {
            bool ok = false;
            if (action == "save") ok = backend.saveProfile(name);
            else if (action == "apply") ok = backend.applyProfile(name);
            else if (action == "delete") ok = backend.deleteProfile(name);
            else return failWith(kUsage);
            if (!ok) return failWith(lastError);
            if (json) print(QJsonObject{{"ok", true}, {"profile", name}});
            return 0;
        }
    }

    err() << kUsage;
    return 1;
}
