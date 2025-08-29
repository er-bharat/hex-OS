#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QProcess>
#include <LayerShellQt/window.h>
#include <QObject>

// ----------------- AppLauncher -----------------
class AppLauncher : public QObject {
    Q_OBJECT
public:
    explicit AppLauncher(QObject *parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE void launchKitty() {
        QProcess::startDetached("hexlauncher");
    }
};

// ----------------- main -----------------
int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);

    // Register AppLauncher for QML
    qmlRegisterType<AppLauncher>("App", 1, 0, "AppLauncher");

    QQmlApplicationEngine engine;
    const QUrl url(QStringLiteral("qrc:/main.qml"));
    engine.load(url);

    if (engine.rootObjects().isEmpty())
        return -1;

    QQuickWindow *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!window)
        return -1;

    // ----------------- LayerShell setup -----------------
    auto layerWindow = LayerShellQt::Window::get(window);
    layerWindow->setLayer(LayerShellQt::Window::LayerOverlay);
    layerWindow->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
    layerWindow->setAnchors(LayerShellQt::Window::Anchors(
        LayerShellQt::Window::AnchorTop |
        LayerShellQt::Window::AnchorRight
    ));
    layerWindow->setExclusiveZone(-1);

    window->setFlags(Qt::FramelessWindowHint |
    Qt::WindowStaysOnTopHint |
    Qt::BypassWindowManagerHint);

    window->showFullScreen();

    return app.exec();
}

#include "main.moc"
