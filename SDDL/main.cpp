#include "lockmanager.h"
#include <LayerShellQt/window.h>
#include <QDebug>
#include <QFileInfo>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QSettings>
#include <QStandardPaths>
#include <QDir>

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);

    QString qmlFile = "qrc:/qml/main.qml"; // Default QML path
    QString customPath;

    // Parse -c or --config argument
    for (int i = 1; i < argc; ++i) {
        if ((QString(argv[i]) == "-c" || QString(argv[i]) == "--config")) {
            if (i + 1 < argc) {
                QFileInfo fileInfo(argv[i + 1]);
                if (fileInfo.exists() && fileInfo.isFile()) {
                    customPath = QUrl::fromLocalFile(fileInfo.absoluteFilePath()).toString();
                } else {
                    qWarning() << "Custom QML file not found:" << argv[i + 1];
                }
            } else {
                qWarning() << "No config file specified after" << argv[i];
            }
            break;
        }
    }

    QQmlApplicationEngine engine;

    // Instantiate and expose LockManager
    LockManager lockManager;
    engine.rootContext()->setContextProperty("lockManager", &lockManager);

    // Expose system username (try USER, fallback to USERNAME)
    QString userName = qgetenv("USER");
    if (userName.isEmpty())
        userName = qgetenv("USERNAME");
    engine.rootContext()->setContextProperty("systemUsername", userName);

    // Read wallpaper path from ~/.config/hexlauncher/apps.ini
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    QDir hexDir(QDir(configDir).filePath("hexlauncher"));
    QString configPath = hexDir.filePath("apps.ini");

    QString wallpaperPath;
    QSettings settings(configPath, QSettings::IniFormat);
    if (settings.contains("Wallpaper/file")) {
        QString path = settings.value("Wallpaper/file").toString();
        if (QFileInfo::exists(path)) {
            wallpaperPath = QUrl::fromLocalFile(path).toString(); // Convert to URL for QML
        } else {
            qWarning() << "Wallpaper file not found:" << path;
        }
    } else {
        qWarning() << "No Wallpaper/file entry found in" << configPath;
    }

    // Expose wallpaperPath to QML
    engine.rootContext()->setContextProperty("wallpaperPath", wallpaperPath);

    // Read all keys in the [gen] group
    settings.beginGroup("gen");

    QVariantMap AppModel;

    if (!settings.childKeys().isEmpty()) {
        AppModel["HexWidth"] = settings.value("HexWidth", 200).toInt();
        AppModel["HexHeight"] = settings.value("HexHeight", 220).toInt();
        AppModel["HexMargin"] = settings.value("HexMargin", 12).toInt();
        AppModel["BorderWidth"] = settings.value("BorderWidth", 4).toInt();
        AppModel["IconGrid"] = settings.value("IconGrid", 5).toInt();
        AppModel["IconPpage"] = settings.value("IconPpage", 14).toInt();
        AppModel["Color"] = settings.value("Color", "#1b1f2a").toString();
        AppModel["BorderColor"] = settings.value("BorderColor", "#FF00FFFF").toString();
        AppModel["HoveredColor"] = settings.value("HoveredColor", "#d900ff00").toString();
        AppModel["BorderHoveredColor"] = settings.value("BorderHoveredColor", "red").toString();
        AppModel["AnimationDuration"] = settings.value("AnimationDuration", 300).toInt();
        AppModel["AnimationScale"] = settings.value("AnimationScale", 1.05).toDouble();
        AppModel["mainFont"] = settings.value("mainFont", "Transducer test").toString();
        AppModel["subFont"] = settings.value("subFont", "Roboto").toString();
    } else {
        qWarning() << "No [gen] group found in" << configPath;
    }

    settings.endGroup();

    // Expose AppModel map to QML
    engine.rootContext()->setContextProperty("AppModel", QVariant::fromValue(AppModel));

    // Load either custom or default QML
    QUrl qmlUrl = customPath.isEmpty() ? QUrl(qmlFile) : QUrl(customPath);
    engine.load(qmlUrl);

    // Fallback to default if custom load failed
    if (engine.rootObjects().isEmpty() && !customPath.isEmpty()) {
        qWarning() << "Failed to load custom QML, falling back to default.";
        engine.load(QUrl(qmlFile));
    }

    if (engine.rootObjects().isEmpty())
        return -1;

    // Configure LayerShell
    QQuickWindow* window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
    auto layerWindow = LayerShellQt::Window::get(window);
    layerWindow->setLayer(LayerShellQt::Window::LayerOverlay);
    layerWindow->setScope("lockscreen");

    layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityExclusive);
    layerWindow->setAnchors({ LayerShellQt::Window::AnchorTop,
        LayerShellQt::Window::AnchorBottom,
        LayerShellQt::Window::AnchorLeft,
        LayerShellQt::Window::AnchorRight });
    layerWindow->setExclusiveZone(0);

    window->setFlags(Qt::Window | Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint);

    // Show fullscreen (lockscreen)
    window->showFullScreen();

    return app.exec();
}
