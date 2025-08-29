// main.cpp

#include <LayerShellQt/window.h>
#include <QAbstractListModel>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QLocalServer>
#include <QLocalSocket>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <algorithm>

class AppModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int hexWidth READ getHexWidth CONSTANT)
    Q_PROPERTY(int hexHeight READ getHexHeight CONSTANT)
    Q_PROPERTY(int hexMargin READ getHexMargin CONSTANT)
    Q_PROPERTY(int borderWidth READ getBorderWidth CONSTANT)
    Q_PROPERTY(int iconGrid READ getIconGrid CONSTANT)
    Q_PROPERTY(int iconPpage READ getIconPpage CONSTANT)
    Q_PROPERTY(int animationDuration READ getAnimationDuration CONSTANT)
    Q_PROPERTY(double animationScale READ getAnimationScale CONSTANT)
    Q_PROPERTY(QString hoveredColor READ getHoveredColor CONSTANT)
    Q_PROPERTY(QString borderHoveredColor READ getBorderHoveredColor CONSTANT)
    Q_PROPERTY(QString fillColor READ getFillColor CONSTANT)
    Q_PROPERTY(QString backgroundColor READ getBackgroundColor CONSTANT)
    Q_PROPERTY(QString borderColor READ getBorderColor CONSTANT)
    Q_PROPERTY(QString apiKey READ getApiKey CONSTANT)
    Q_PROPERTY(QString weatherLocation READ getWeatherLocation CONSTANT)
    Q_PROPERTY(QString mainFont READ getMainFont CONSTANT)
    Q_PROPERTY(QString subFont READ getSubFont CONSTANT)



public:
    enum Roles {
        NameRole = Qt::DisplayRole,
        IconRole = Qt::UserRole + 1,
        ExecRole
    };

    struct AppEntry {
        QString name;
        QString icon;
        QString exec;
    };

    explicit AppModel(QObject* parent = nullptr)
        : QAbstractListModel(parent)
    {
    }

    int rowCount(const QModelIndex& = QModelIndex()) const override
    {
        return apps.size();
    }

    QVariant data(const QModelIndex& index, int role) const override
    {
        if (!index.isValid() || index.row() >= apps.size())
            return {};
        const AppEntry& app = apps.at(index.row());
        switch (role) {
        case NameRole:
            return app.name;
        case IconRole:
            return app.icon;
        case ExecRole:
            return app.exec;
        }
        return {};
    }
    Q_INVOKABLE QVariantMap get(int index) const
    {
        if (index < 0 || index >= apps.size())
            return QVariantMap();

        const AppEntry& app = apps.at(index);
        QVariantMap map;
        map["name"] = app.name;
        map["icon"] = app.icon;
        map["exec"] = app.exec;
        return map;
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {
            { NameRole, "name" },
            { IconRole, "icon" },
            { ExecRole, "exec" }
        };
    }

    Q_INVOKABLE void loadFromIni(const QString& path)
    {
        m_configPath = path;
        apps.clear();
        QSettings settings(path, QSettings::IniFormat);

        settings.beginGroup("gen");
        m_hexWidth = settings.value("HexWidth", 200).toInt();
        m_hexHeight = settings.value("HexHeight", 190).toInt();
        m_hexMargin = settings.value("HexMargin", 10).toInt();
        m_borderWidth = settings.value("BorderWidth", 3).toInt();
        m_iconGrid = settings.value("IconGrid", 3).toInt();
        m_iconPpage = settings.value("IconPpage", 3).toInt();
        m_animationDuration = settings.value("AnimationDuration", 300).toInt();
        m_animationScale = settings.value("AnimationScale", 1.05).toDouble();
        m_fillColor = settings.value("FillColor", "#333333cc").toString();
        m_backgroundColor = settings.value("BackgroundColor", "transparent").toString();
        m_borderColor = settings.value("BorderColor", "white").toString();
        m_hoveredColor = settings.value("HoveredColor", "#555555cc").toString();
        m_borderHoveredColor = settings.value("BorderHoveredColor", "#ffffff").toString();
        m_apiKey = settings.value("ApiKey", "").toString();
        m_weatherLocation = settings.value("weatherLocation", "Madhubani").toString();
        m_mainFont = settings.value("mainFont", "Orbitron").toString();
        m_subFont = settings.value("subFont", "Roboto").toString();
        settings.endGroup();

        QStringList groups = settings.childGroups();
        std::sort(groups.begin(), groups.end(), [](const QString& a, const QString& b) {
            QRegularExpression re(R"(\d+)");
            auto ma = re.match(a), mb = re.match(b);
            int na = ma.hasMatch() ? ma.captured(0).toInt() : 0;
            int nb = mb.hasMatch() ? mb.captured(0).toInt() : 0;
            return na < nb;
        });

        for (const QString& group : groups) {
            if (group == "gen" || group == "Widgets" || group == "Wallpaper")
                continue;
            settings.beginGroup(group);
            AppEntry entry {
                settings.value("Name").toString(),
                resolveIcon(settings.value("Icon").toString()),
                sanitizeExec(settings.value("Exec").toString())
            };
            settings.endGroup();
            apps.append(entry);
        }

        emit countChanged();
    }

    // Helper function to calculate relevance
    int relevanceScore(const QString &content, const QString &query) {
        QString lowerContent = content.toLower();
        QString lowerQuery = query.toLower();

        if (lowerContent == lowerQuery) return 100;        // exact match
        if (lowerContent.startsWith(lowerQuery)) return 50; // prefix match
        if (lowerContent.contains(lowerQuery)) return 10; // partial match
        return 0;                                         // no match
    }

    // Helper struct to store app + relevance
    struct ScoredApp {
        AppEntry app;
        int score;
    };

    // Helper function to calculate relevance with app name prioritized
    int relevanceScore(const QString &name, const QString &content, const QString &query) {
        QString lowerName = name.toLower();
        QString lowerContent = content.toLower();
        QString lowerQuery = query.toLower();

        if (lowerName == lowerQuery) return 100;        // exact match in app name
        if (lowerName.startsWith(lowerQuery)) return 80; // prefix match in app name
        if (lowerName.contains(lowerQuery)) return 60;  // partial match in app name

        // Check other fields with lower weight
        if (lowerContent.contains(lowerQuery)) return 10;

        return 0; // no match
    }

    Q_INVOKABLE void searchDesktopFiles(const QString &query)
    {
        apps.clear();
        const QStringList locations = {
            "/usr/share/applications",
            QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation)
        };

        int maxCount = m_iconGrid * m_iconGrid;
        bool foundAny = false;

        QVector<ScoredApp> scoredApps;
        QSet<QString> seenApps; // avoid duplicates
        QString lowerQuery = query.toLower();

        auto computeKey = [](const QString &name, const QString &exec) {
            return name + "|" + exec;
        };

        auto matchesQuery = [&](const QString &content) -> bool {
            QString lowerContent = content.toLower();
            if (lowerContent.contains(lowerQuery))
                return true;

            QStringList queryWords = lowerQuery.split(' ', Qt::SkipEmptyParts);
            return std::any_of(queryWords.begin(), queryWords.end(), [&](const QString &word){
                return lowerContent.contains(word);
            });
        };

        for (const QString &dirPath : locations) {
            QDir dir(dirPath);
            QFileInfoList fileList = dir.entryInfoList(QStringList() << "*.desktop", QDir::Files);

            for (const QFileInfo &fileInfo : fileList) {
                if (scoredApps.size() >= maxCount)
                    break;

                QFile file(fileInfo.absoluteFilePath());
                if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
                    continue;

                QTextStream in(&file);
                QString currentGroup;
                QMap<QString, QString> desktopData;
                QMap<QString, QMap<QString, QString>> actionGroups;

                while (!in.atEnd()) {
                    QString line = in.readLine().trimmed();
                    if (line.isEmpty() || line.startsWith('#'))
                        continue;

                    if (line.startsWith('[') && line.endsWith(']')) {
                        currentGroup = line.mid(1, line.length() - 2);
                        continue;
                    }

                    int eqIndex = line.indexOf('=');
                    if (eqIndex < 0) continue;

                    QString key = line.left(eqIndex).trimmed();
                    QString value = line.mid(eqIndex + 1).trimmed();

                    if (currentGroup == "Desktop Entry") {
                        desktopData[key] = value;
                    } else if (currentGroup.startsWith("Desktop Action")) {
                        actionGroups[currentGroup][key] = value;
                    }
                }

                // Filter apps not to show
                bool noDisplay = desktopData.value("NoDisplay", "false").toLower() == "true";
                bool terminal = desktopData.value("Terminal", "false").toLower() == "true";
                QString onlyShowIn = desktopData.value("OnlyShowIn", "");
                QStringList excludedDesktops = { "LXQt", "XFCE", "MATE" };
                QStringList onlyShowList = onlyShowIn.split(';', Qt::SkipEmptyParts);

                bool isExcluded = std::any_of(excludedDesktops.begin(), excludedDesktops.end(),
                                              [&](const QString &env){ return onlyShowList.contains(env, Qt::CaseInsensitive); });

                if (noDisplay || terminal || isExcluded)
                    continue;

                QString name = desktopData.value("Name", "");
                QString exec = desktopData.value("Exec", "");
                QString icon = desktopData.value("Icon", "");

                // Combine searchable content including translations and keywords
                QString searchContent;
                for (const QString &key : desktopData.keys()) {
                    if (key.startsWith("GenericName") || key.startsWith("Comment") || key.startsWith("Keywords") || key.startsWith("Categories"))
                        searchContent += desktopData[key] + " ";
                    if (key.startsWith("Name[")) // translated names
                        searchContent += desktopData[key] + " ";
                }

                QString combinedContent = (name + " " + searchContent + " " + exec + " " + icon).toLower();

                // Add main app if matches query
                if (matchesQuery(combinedContent)) {
                    QString keyMain = computeKey(name, exec);
                    if (!seenApps.contains(keyMain)) {
                        AppEntry entry { name, resolveIcon(icon), sanitizeExec(exec) };
                        int score = relevanceScore(name, searchContent, query);
                        scoredApps.append({ entry, score });
                        seenApps.insert(keyMain);
                        foundAny = true;
                    }
                }

                // Handle sub-actions as separate searchable items
                for (auto it = actionGroups.begin(); it != actionGroups.end(); ++it) {
                    const auto &actionData = it.value();
                    QString actionName = actionData.value("Name", "");
                    QString actionExec = actionData.value("Exec", exec); // fallback to main exec
                    QString actionIcon = actionData.value("Icon", icon);

                    // Include main app name + sub-action name + translations + exec + icon
                    QStringList actionParts;
                    actionParts << name << actionName << actionExec << actionIcon;

                    for (auto subIt = actionData.begin(); subIt != actionData.end(); ++subIt) {
                        if (subIt.key().startsWith("Name[") || subIt.key().startsWith("Keywords") || subIt.key().startsWith("Comment") || subIt.key().startsWith("GenericName"))
                            actionParts << subIt.value();
                    }

                    QString actionContent = actionParts.join(" ").toLower();

                    if (!matchesQuery(actionContent))
                        continue;

                    QString actionKey = computeKey(actionName, actionExec) + "|" + actionParts.join("|");
                    if (seenApps.contains(actionKey))
                        continue;

                    int actionScore = relevanceScore(actionName, actionContent, query);
                    if (actionScore <= 0)
                        actionScore = 5; // minimal score

                        AppEntry actionEntry { actionName, resolveIcon(actionIcon), sanitizeExec(actionExec) };
                    scoredApps.append({ actionEntry, actionScore });

                    seenApps.insert(actionKey);
                    foundAny = true;
                }
            }
        }

        // Sort by relevance then alphabetically
        std::sort(scoredApps.begin(), scoredApps.end(), [](const ScoredApp &a, const ScoredApp &b) {
            if (a.score != b.score)
                return a.score > b.score;
            return a.app.name.compare(b.app.name, Qt::CaseInsensitive) < 0;
        });

        for (const ScoredApp &s : scoredApps)
            apps.append(s.app);

        if (!foundAny)
            apps.append({ "No results found", "", "" });

        emit countChanged();
    }


    Q_INVOKABLE void loadAllDesktopFiles()
    {
        apps.clear();

        const QStringList locations = {
            "/usr/share/applications",
            QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation)
        };

        for (const QString& dirPath : locations) {
            QDir dir(dirPath);
            QFileInfoList fileList = dir.entryInfoList(QStringList() << "*.desktop", QDir::Files);

            for (const QFileInfo& fileInfo : fileList) {
                QSettings desktopFile(fileInfo.absoluteFilePath(), QSettings::IniFormat);
                desktopFile.beginGroup("Desktop Entry");

                bool noDisplay = desktopFile.value("NoDisplay", false).toBool();
                QString onlyShowIn = desktopFile.value("OnlyShowIn").toString();
                QStringList excludedDesktops = { "LXQt", "XFCE", "MATE" };
                QStringList onlyShowList = onlyShowIn.split(';', Qt::SkipEmptyParts);
                bool terminal = desktopFile.value("Terminal", false).toBool();

                bool isExcluded = std::any_of(excludedDesktops.begin(), excludedDesktops.end(), [&](const QString& env) {
                    return onlyShowList.contains(env, Qt::CaseInsensitive);
                });

                if (noDisplay || isExcluded || terminal) {
                    desktopFile.endGroup();
                    continue;
                }

                QString name = desktopFile.value("Name").toString();
                QString exec = desktopFile.value("Exec").toString();
                QString icon = desktopFile.value("Icon").toString();

                apps.append({ name,
                    resolveIcon(icon),
                    sanitizeExec(exec) });

                desktopFile.endGroup();
            }
        }

        // Sort apps by name, case-insensitive
        std::sort(apps.begin(), apps.end(), [](const auto& a, const auto& b) {
            return a.name.toLower() < b.name.toLower();
        });

        emit countChanged();
    }

    int getHexWidth() const { return m_hexWidth; }
    int getHexHeight() const { return m_hexHeight; }
    int getHexMargin() const { return m_hexMargin; }
    int getBorderWidth() const { return m_borderWidth; }
    int getIconGrid() const { return m_iconGrid; }
    int getIconPpage() const { return m_iconPpage; }
    int getAnimationDuration() const { return m_animationDuration; }
    double getAnimationScale() const { return m_animationScale; }
    QString getFillColor() const { return m_fillColor; }
    QString getBackgroundColor() const { return m_backgroundColor; }
    QString getBorderColor() const { return m_borderColor; }
    QString getHoveredColor() const { return m_hoveredColor; }
    QString getBorderHoveredColor() const { return m_borderHoveredColor; }
    QString getApiKey() const { return m_apiKey; }
    QString getWeatherLocation() const { return m_weatherLocation; }
    QString getMainFont() const { return m_mainFont; }
    QString getSubFont() const { return m_subFont; }



Q_SIGNALS:
    void countChanged();

private:
    QList<AppEntry> apps;
    QString m_configPath;
    int m_hexWidth = 200, m_hexHeight = 190, m_hexMargin = 10;
    int m_borderWidth = 3, m_iconGrid = 3, m_iconPpage = 3;
    int m_animationDuration = 300;
    double m_animationScale = 1.05;
    QString m_fillColor = "#333333cc", m_backgroundColor = "transparent", m_borderColor = "white";
    QString m_hoveredColor = "#555555cc", m_borderHoveredColor = "#ffffff";
    QString m_apiKey;
    QString m_weatherLocation;
    QString m_mainFont;
    QString m_subFont;

    QString resolveIcon(const QString& name)
    {
        if (QFile::exists(name))
            return name;

        QString home = QDir::homePath();

        const QStringList iconDirs = {
            "/usr/share/icons/hicolor/256x256/apps/",
            "/usr/share/icons/hicolor/128x128/apps/",
            "/usr/share/icons/hicolor/64x64/apps/",
            "/usr/share/icons/hicolor/48x48/apps/",
            "/usr/share/icons/hicolor/scalable/apps/",
            "/usr/share/pixmaps/",
            "/usr/share/icons/breeze/apps/64/",
            home + "/.local/share/icons/hicolor/256x256/apps/",
            "/usr/share/icons/breeze/apps/48/"

        };
        for (const QString& dir : iconDirs) {
            if (QFile::exists(dir + name + ".png"))
                return dir + name + ".png";
            if (QFile::exists(dir + name + ".svg"))
                return dir + name + ".svg";
        }
        return "";
    }

    QString sanitizeExec(const QString& exec) const
    {
        QStringList parts = exec.split(' ', Qt::SkipEmptyParts);
        auto it = std::remove_if(parts.begin(), parts.end(), [](const QString& part) {
            return part.startsWith('%');
        });
        parts.erase(it, parts.end());
        return parts.join(' ');
    }
};

class LauncherHelper : public QObject {
    Q_OBJECT
public slots:
    void launch(const QString& command)
    {
        // Remove field codes like %U, %u, %f, etc.
        QString cleaned = command;
        cleaned.remove(QRegularExpression(R"(%[a-zA-Z])")); // remove %U, %u, %f, etc.

        QStringList parts = QProcess::splitCommand(cleaned.trimmed());
        if (!parts.isEmpty()) {
            QString program = parts.takeFirst();
            QProcess::startDetached(program, parts);
        }
    }

    Q_INVOKABLE void launchAndRefresh(const QString& command, QObject* modelObj)
    {
        QString cleaned = command;
        cleaned.remove(QRegularExpression(R"(%[a-zA-Z])"));

        QStringList parts = QProcess::splitCommand(cleaned.trimmed());
        if (parts.isEmpty())
            return;

        QString program = parts.takeFirst();
        QProcess::startDetached(program, parts);

        // Refresh multiple times after app launch
        QTimer* timer = new QTimer(modelObj); // parent to modelObj for safe cleanup
        int* refreshCount = new int(0); // counter on heap for lambda capture

        timer->setInterval(400); // adjust delay between refreshes if needed

        QObject::connect(timer, &QTimer::timeout, [timer, modelObj, refreshCount]() {
            QProcess proc;
            proc.start("list-windows");
            proc.waitForFinished(700);

            QMetaObject::invokeMethod(modelObj, "refresh", Qt::QueuedConnection);
            (*refreshCount)++;

            if (*refreshCount >= 3) {
                timer->stop();
                timer->deleteLater();
                delete refreshCount;
            }
        });

        // Start after slight delay
        QTimer::singleShot(700, timer, SLOT(start()));
    }
};

class RunningWindowModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum Roles {
        TitleRole = Qt::UserRole + 1,
        AppIdRole,
        FocusedRole,
        IconRole
    };

    Q_INVOKABLE void refresh()
    {
        const QString iniPath = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/hexlauncher/windows.ini";
        loadFromIni(iniPath);
    }

    Q_INVOKABLE void activate(int index)
    {
        if (index < 0 || index >= windows.size())
            return;

        QString title = windows[index].title;
        QString program = "list-windows";
        QStringList arguments = { "--activate", title };

        QProcess::startDetached(program, arguments);
    }

    Q_INVOKABLE void close(int index)
    {
        if (index < 0 || index >= windows.size())
            return;

        QString title = windows[index].title;
        QString program = "list-windows";
        QStringList closeArgs = { "--close", title };

        if (QProcess::startDetached(program, closeArgs)) {
            // Refresh once after 300ms
            QTimer::singleShot(300, this, &RunningWindowModel::refresh);
        }
    }



    struct WindowEntry {
        QString title;
        QString app_id;
        bool focused;
        QString icon;
    };

    RunningWindowModel(QObject* parent = nullptr)
        : QAbstractListModel(parent)
    {
        // First immediate refresh
        refresh(); // immediate attempt
        QTimer::singleShot(300, this, &RunningWindowModel::refresh); // catch INI write

    }

    int rowCount(const QModelIndex& parent = QModelIndex()) const override
    {
        Q_UNUSED(parent);
        return windows.size();
    }

    QVariant data(const QModelIndex& index, int role) const override
    {
        if (!index.isValid() || index.row() >= windows.size())
            return {};

        const auto& win = windows[index.row()];
        switch (role) {
        case TitleRole:
            return win.title;
        case AppIdRole:
            return win.app_id;
        case FocusedRole:
            return win.focused;
        case IconRole:
            return win.icon;
        default:
            return {};
        }
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {
            { TitleRole, "title" },
            { AppIdRole, "app_id" },
            { FocusedRole, "focused" },
            { IconRole, "icon" }
        };
    }

private:
    QList<WindowEntry> windows;

    void loadFromIni(const QString& path)
    {
        if (!QFile::exists(path))
            return;

        beginResetModel();
        windows.clear();

        QSettings ini(path, QSettings::IniFormat);
        for (const QString& group : ini.childGroups()) {
            ini.beginGroup(group);
            QString title = ini.value("Title").toString();
            QString app_id = ini.value("AppID").toString();
            bool focused = ini.value("Focused").toBool();
            QString iconName = findIconNameFromDesktopFile(app_id);
            QString iconPath = resolveIcon(iconName);
            windows.append({ title, app_id, focused, iconPath });
            ini.endGroup();
        }

        endResetModel();
    }

    QString findIconNameFromDesktopFile(const QString& appId) const
    {
        const QStringList desktopFileNames = {
            appId + ".desktop",
            appId.toLower() + ".desktop"
        };

        const QStringList desktopDirs = {
            QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation),
            "/usr/share/applications",
            "/usr/local/share/applications"
        };

        for (const QString& dirPath : desktopDirs) {
            for (const QString& fileName : desktopFileNames) {
                QString filePath = QDir(dirPath).filePath(fileName);
                if (!QFile::exists(filePath))
                    continue;

                QSettings desktopFile(filePath, QSettings::IniFormat);
                desktopFile.beginGroup("Desktop Entry");
                QString iconName = desktopFile.value("Icon").toString();
                desktopFile.endGroup();

                if (!iconName.isEmpty())
                    return iconName;
            }
        }

        return "";
    }

    QString resolveIcon(const QString& name) const
    {
        if (name.isEmpty())
            return ":/icons/default.png";

        if (QFile::exists(name))
            return name;

        const QStringList iconDirs = {
            "/usr/share/icons/hicolor/256x256/apps/",
            "/usr/share/icons/hicolor/128x128/apps/",
            "/usr/share/icons/hicolor/64x64/apps/",
            "/usr/share/icons/hicolor/48x48/apps/",
            "/usr/share/icons/hicolor/scalable/apps/",
            "/usr/share/pixmaps/",
            "/usr/share/icons/breeze/apps/64/",
            "/usr/share/icons/breeze/apps/48/",
            QDir::homePath() + "/.local/share/icons/hicolor/256x256/apps/"
        };

        for (const QString& dir : iconDirs) {
            if (QFile::exists(dir + name + ".png"))
                return dir + name + ".png";
            if (QFile::exists(dir + name + ".svg"))
                return dir + name + ".svg";
        }

        return ":/icons/default.png";
    }
};

class NetworkInfoProvider : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString networkType READ networkType NOTIFY networkChanged)
    Q_PROPERTY(QString networkName READ networkName NOTIFY networkChanged)

public:
    explicit NetworkInfoProvider(QObject* parent = nullptr)
        : QObject(parent)
    {
        updateNetworkInfo();
    }

    QString networkType() const { return m_type; }
    QString networkName() const { return m_name; }

public slots:
    void updateNetworkInfo()
    {
        QProcess proc;
        proc.start("ip", { "route", "get", "8.8.8.8" });
        proc.waitForFinished();
        QString output = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();

        QRegularExpression ifaceRegex(R"(dev\s+(\w+))");
        QRegularExpressionMatch match = ifaceRegex.match(output);
        if (!match.hasMatch()) {
            m_type = "Disconnected";
            m_name = "";
            emit networkChanged();
            return;
        }

        QString iface = match.captured(1);
        QString newType;
        QString newName;

        if (iface.startsWith("wlan")) {
            newType = "Wi-Fi";

            QProcess wifiProc;
            wifiProc.start("iwgetid", QStringList() << "-r");
            wifiProc.waitForFinished();
            newName = QString::fromUtf8(wifiProc.readAllStandardOutput()).trimmed();

        } else if (iface.startsWith("eth")) {
            newType = "Ethernet";
            newName = iface;
        } else if (iface.startsWith("usb") || iface.contains("rndis") || iface.contains("enx") || iface.contains("enp")) {
            newType = "USB Tethering";
            newName = iface;
        } else {
            newType = "Unknown";
            newName = iface;
        }

        if (newType != m_type || newName != m_name) {
            m_type = newType;
            m_name = newName;
            emit networkChanged();
        }
    }

    void openNetworkManager()
    {
        QProcess::startDetached("nmqt");
    }

signals:
    void networkChanged();

private:
    QString m_type = "Disconnected";
    QString m_name = "";
};

class BatteryInfoProvider : public QObject {
    Q_OBJECT
    Q_PROPERTY(int percentage READ percentage NOTIFY batteryChanged)
    Q_PROPERTY(QString status READ status NOTIFY batteryChanged)

public:
    explicit BatteryInfoProvider(QObject* parent = nullptr)
        : QObject(parent)
    {
        updateBattery();
    }

    int percentage() const { return m_percentage; }
    QString status() const { return m_status; }

public slots:
    void updateBattery()
    {
        QString basePath = "/sys/class/power_supply/";

        // Try to find battery directory (BAT0 or BAT1)
        QString batteryDir;
        QDir powerDir(basePath);
        for (const QString& entry : powerDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            if (entry.startsWith("BAT")) {
                batteryDir = basePath + entry;
                break;
            }
        }

        if (batteryDir.isEmpty()) {
            m_percentage = -1;
            m_status = "Unavailable";
            emit batteryChanged();
            return;
        }

        QFile capacityFile(batteryDir + "/capacity");
        QFile statusFile(batteryDir + "/status");

        if (capacityFile.open(QIODevice::ReadOnly) && statusFile.open(QIODevice::ReadOnly)) {
            int percent = QString(capacityFile.readAll()).trimmed().toInt();
            QString stat = QString(statusFile.readAll()).trimmed();

            if (percent != m_percentage || stat != m_status) {
                m_percentage = percent;
                m_status = stat;
                emit batteryChanged();
            }
        } else {
            m_percentage = -1;
            m_status = "Unknown";
            emit batteryChanged();
        }
    }

signals:
    void batteryChanged();

private:
    int m_percentage = -1;
    QString m_status = "Unknown";
};

class PowerControl : public QObject {
    Q_OBJECT
public:
    explicit PowerControl(QObject* parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE void shutdown() { QProcess::startDetached("systemctl", {"poweroff"}); }
    Q_INVOKABLE void reboot()   { QProcess::startDetached("systemctl", {"reboot"}); }
    Q_INVOKABLE void suspend()  { QProcess::startDetached("systemctl", {"suspend"}); }
    Q_INVOKABLE void logout() {
        QProcess::startDetached("bash", {"-c", "swaymsg exit || hyprctl dispatch exit || labwc -e || loginctl terminate-user $USER"});
        QCoreApplication::quit(); // optional: quit launcher immediately
    }

};

class OsdControl : public QObject {
    Q_OBJECT
public:
    explicit OsdControl(QObject* parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE void volUp()   { QProcess::startDetached("osd-client", {"--volup"}); }
    Q_INVOKABLE void volDown() { QProcess::startDetached("osd-client", {"--voldown"}); }
    Q_INVOKABLE void volMute() { QProcess::startDetached("osd-client", {"--mute"}); }

    Q_INVOKABLE void dispUp()   { QProcess::startDetached("osd-client", {"--dispup"}); }
    Q_INVOKABLE void dispDown() { QProcess::startDetached("osd-client", {"--dispdown"}); }
};


// Ensure default keys in [Widgets] section
void ensureWidgetsSection(const QString &path)
{
    QSettings settings(path, QSettings::IniFormat);
    settings.beginGroup("Widgets");
    if (!settings.contains("hexClock"))   settings.setValue("hexClock", true);
    if (!settings.contains("hexNetwork")) settings.setValue("hexNetwork", true);
    if (!settings.contains("hexBattery")) settings.setValue("hexBattery", true);
    if (!settings.contains("hexWeather")) settings.setValue("hexWeather", true);
    if (!settings.contains("hexPower"))   settings.setValue("hexPower", true);
    if (!settings.contains("sinBg"))      settings.setValue("sinBg", false);
    if (!settings.contains("sciFiBg"))    settings.setValue("sciFiBg", true);
    settings.endGroup();
    settings.sync();
}

// Ensure default keys in [Wallpaper] section
void ensureWallpaperSection(const QString &path)
{
    QSettings settings(path, QSettings::IniFormat);
    settings.beginGroup("Wallpaper");
    if (!settings.contains("file"))
        settings.setValue("file", ""); // default: no wallpaper selected
        settings.endGroup();
    settings.sync();
}



int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);
    const QString serverName = "hexlauncher-single-instance";

    // Prevent multiple instances
    QLocalSocket socket;
    socket.connectToServer(serverName);
    if (socket.waitForConnected(100))
        return 0;

    QLocalServer::removeServer(serverName);
    static QLocalServer server;
    if (!server.listen(serverName))
        return 1;

    // Launch list-windows on start
    QString program = "list-windows";
    if (!QProcess::startDetached(program)) {
        qWarning() << "[WARN] Failed to start list-windows!";
    } else {
        qDebug() << "[INFO] list-windows started successfully.";
    }

    //  Define config path once
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/hexlauncher";
    QDir().mkpath(configDir); // ensure directory exists
    QString configPath = configDir + "/apps.ini";

    // Ensure [Widgets] and [Wallpaper] sections exist with defaults
    ensureWidgetsSection(configPath);
    ensureWallpaperSection(configPath);


    //   Load appModel config
    AppModel* model = new AppModel;
    model->loadFromIni(configPath);

    //   Read widget visibility settings from apps.ini
    QSettings settings(configPath, QSettings::IniFormat);
    settings.beginGroup("Widgets");
    bool showClock   = settings.value("hexClock", true).toBool();
    bool showNetwork = settings.value("hexNetwork", true).toBool();
    bool showBattery = settings.value("hexBattery", true).toBool();
    bool showWeather = settings.value("hexWeather", true).toBool();
    bool showPower   = settings.value("hexPower", true).toBool();
    bool showsinBg   = settings.value("sinBg", true).toBool();
    bool showsciFiBg   = settings.value("sciFiBg", true).toBool();
    settings.endGroup();

    //   Set up QML context
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("appModel", model);
    engine.rootContext()->setContextProperty("configPath", configPath);
    engine.rootContext()->setContextProperty("showClock", showClock);
    engine.rootContext()->setContextProperty("showNetwork", showNetwork);
    engine.rootContext()->setContextProperty("showBattery", showBattery);
    engine.rootContext()->setContextProperty("showWeather", showWeather);
    engine.rootContext()->setContextProperty("showPower", showPower);
    engine.rootContext()->setContextProperty("showsinBg", showsinBg);
    engine.rootContext()->setContextProperty("showsciFiBg", showsciFiBg);

    // Other models and providers
    RunningWindowModel* winModel = new RunningWindowModel;
    engine.rootContext()->setContextProperty("runningWindows", winModel);

    NetworkInfoProvider* networkProvider = new NetworkInfoProvider;
    engine.rootContext()->setContextProperty("networkProvider", networkProvider);

    BatteryInfoProvider* batteryProvider = new BatteryInfoProvider;
    engine.rootContext()->setContextProperty("batteryProvider", batteryProvider);

    LauncherHelper launcher;
    engine.rootContext()->setContextProperty("launcher", &launcher);

    PowerControl powerControl;
    engine.rootContext()->setContextProperty("powerControl", &powerControl);

    OsdControl osdControl;
    engine.rootContext()->setContextProperty("osdController", &osdControl);


    // Load QML
    const QUrl url(QStringLiteral("qrc:/main.qml"));
    engine.load(url);
    if (engine.rootObjects().isEmpty())
        return -1;

    // Set up window with LayerShell
    QQuickWindow* window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
    if (!window)
        return -1;

    auto layerWindow = LayerShellQt::Window::get(window);
    layerWindow->setLayer(LayerShellQt::Window::LayerOverlay);
    layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityExclusive);
    layerWindow->setAnchors({
        LayerShellQt::Window::AnchorTop,
        LayerShellQt::Window::AnchorBottom,
        LayerShellQt::Window::AnchorLeft,
        LayerShellQt::Window::AnchorRight
    });
    layerWindow->setExclusiveZone(0);

    window->setFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint);
    window->showFullScreen();

    return app.exec();
}


#include "main.moc"
