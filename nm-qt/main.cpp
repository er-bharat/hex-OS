#include <QApplication>
#include <QDebug>
#include <QInputDialog>
#include <QListWidget>
#include <QMessageBox>
#include <QMetaType>
#include <QProcess>
#include <QPushButton>
#include <QSet>
#include <QTimer>
#include <QVBoxLayout>
#include <QWidget>
#include <QtConcurrent/QtConcurrent>

struct WiFiInfo {
    QString ssid;
    QString security;
    int signal;
    bool isActive;
};

Q_DECLARE_METATYPE(WiFiInfo)

QList<WiFiInfo> getWiFiInfoList()
{
    QProcess proc;
    proc.start("nmcli", { "-t", "-f", "SSID,SECURITY,SIGNAL,ACTIVE", "dev", "wifi", "list" });
    proc.waitForFinished(5000);
    QString output = proc.readAllStandardOutput();
    QStringList lines = output.split('\n', Qt::SkipEmptyParts);

    QSet<QString> seenSsids;
    QList<WiFiInfo> result;

    for (const QString& line : lines) {
        QStringList parts = line.split(':');
        if (parts.size() < 4)
            continue;

        QString ssid = parts[0].trimmed();
        QString security = parts[1].trimmed();
        int signal = parts[2].toInt();
        bool active = parts[3].trimmed() == "yes";

        if (ssid.isEmpty() || seenSsids.contains(ssid))
            continue;
        seenSsids.insert(ssid);
        result.append({ ssid, security, signal, active });
    }

    return result;
}

QString formatNetworkEntry(const WiFiInfo& info)
{
    QString strength;
    if (info.signal >= 75)
        strength = "📶📶📶";
    else if (info.signal >= 50)
        strength = "📶📶";
    else if (info.signal >= 25)
        strength = "📶";
    else
        strength = "❌";

    QString security = info.security.isEmpty() ? "Open" : "🔒";
    return QString("%1 (%2, %3%) %4").arg(info.ssid, security).arg(info.signal).arg(strength);
}

bool deleteExistingConnectionProfile(const QString& ssid)
{
    QProcess proc;
    proc.start("nmcli", { "connection", "delete", "id", ssid });
    proc.waitForFinished(3000);

    QString err = proc.readAllStandardError();
    if (!err.isEmpty() && !err.contains("not found", Qt::CaseInsensitive)) {
        qDebug() << "Delete error:" << err;
        return false;
    }
    return true;
}

bool connectToWiFi(const QString& ssid, const QString& password = QString())
{
    deleteExistingConnectionProfile(ssid);

    QProcess proc;
    QStringList args = { "-w", "10", "dev", "wifi", "connect", ssid };
    if (!password.isEmpty())
        args << "password" << password;

    proc.start("nmcli", args);
    if (!proc.waitForFinished(10000)) {
        QMessageBox::critical(nullptr, "Timeout", "WiFi connection timed out.");
        return false;
    }

    QString out = proc.readAllStandardOutput();
    QString err = proc.readAllStandardError();

    if (out.contains("successfully activated", Qt::CaseInsensitive))
        return true;

    if (err.contains("key-mgmt", Qt::CaseInsensitive)) {
        QMessageBox::critical(nullptr, "Connection Error", "Missing or incorrect WiFi password.");
    } else {
        QMessageBox::critical(nullptr, "Failed", out + "\n" + err);
    }

    qDebug() << "Connect error:" << out << err;
    return false;
}

int main(int argc, char* argv[])
{
    qRegisterMetaType<WiFiInfo>("WiFiInfo");
    qRegisterMetaType<QList<WiFiInfo>>("QList<WiFiInfo>");

    QApplication app(argc, argv);

    QWidget window;
    window.setWindowTitle("Qt6 WiFi Manager (nmcli)");

    QVBoxLayout layout(&window);
    QListWidget listWidget;
    QPushButton scanBtn("Scan WiFi");

    layout.addWidget(&listWidget);
    layout.addWidget(&scanBtn);

    QTimer scanTimer;
    int scanCount = 0;
    const int maxScans = 3;

    auto scanWiFi = [&]() {
        if (scanCount >= maxScans) {
            scanTimer.stop();
            return;
        }

        scanCount++;
        listWidget.clear();
        listWidget.addItem("🔄 Scanning...");

        QtConcurrent::run([&listWidget]() {
            try {
                QList<WiFiInfo> wifiList = getWiFiInfoList();

                std::sort(wifiList.begin(), wifiList.end(), [](const WiFiInfo& a, const WiFiInfo& b) {
                    return a.signal > b.signal;
                });

                QMetaObject::invokeMethod(&listWidget, [wifiList, &listWidget]() {
                    listWidget.clear();

                    for (const WiFiInfo& info : wifiList) {
                        QString text = formatNetworkEntry(info);
                        QListWidgetItem* item = new QListWidgetItem(text);
                        QVariant var;
                        var.setValue(info);
                        item->setData(Qt::UserRole, var);

                        if (info.isActive) {
                            item->setText("✅ " + item->text());
                            QFont f = item->font();
                            f.setBold(true);
                            item->setFont(f);
                        }

                        listWidget.addItem(item);
                    }
                });
            } catch (...) {
                qDebug() << "Exception occurred during WiFi scan.";
            }
        });
    };

    QObject::connect(&scanBtn, &QPushButton::clicked, [&]() {
        scanCount = 0;
        scanTimer.start();
        scanWiFi();
    });

    QObject::connect(&listWidget, &QListWidget::itemClicked, [&](QListWidgetItem* item) {
        WiFiInfo info = item->data(Qt::UserRole).value<WiFiInfo>();

        if (info.isActive) {
            QMessageBox::information(&window, "Already Connected", "You are already connected to " + info.ssid);
            return;
        }

        if (info.security.isEmpty()) {
            if (connectToWiFi(info.ssid)) {
                QMessageBox::information(&window, "Connected", "Connected to " + info.ssid);
                scanWiFi();
            } else {
                QMessageBox::critical(&window, "Failed", "Failed to connect to " + info.ssid);
            }
            return;
        }

        bool ok;
        QString password = QInputDialog::getText(&window, "WiFi Password",
            "Enter password for " + info.ssid,
            QLineEdit::Password, "", &ok);
        if (ok && !password.isEmpty()) {
            if (connectToWiFi(info.ssid, password)) {
                QMessageBox::information(&window, "Connected", "Connected to " + info.ssid);
                scanWiFi();
            } else {
                QMessageBox::critical(&window, "Failed", "Failed to connect to " + info.ssid);
            }
        }
    });

    QTimer::singleShot(0, scanWiFi);
    scanTimer.setInterval(5000);
    QObject::connect(&scanTimer, &QTimer::timeout, scanWiFi);
    scanTimer.start();

    window.resize(450, 350);
    window.show();

    return app.exec();
}
