#include "wlr-foreign-toplevel-management-unstable-v1-client-protocol.h"
#include <QDir>
#include <QSettings>
#include <QProcess>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QThread>
#include <cstring>
#include <iostream>
#include <map>
#include <wayland-client.h>

bool running = true;
bool exit_after_first_dump = true;

extern "C" {
    extern const struct wl_interface zwlr_foreign_toplevel_manager_v1_interface;
    extern const struct wl_interface zwlr_foreign_toplevel_handle_v1_interface;
}

struct wl_display* display = nullptr;
struct wl_registry* registry = nullptr;
struct zwlr_foreign_toplevel_manager_v1* toplevel_manager = nullptr;
struct wl_seat* seat = nullptr;

struct WindowInfo {
    std::string title;
    std::string app_id;
    bool focused = false;
    bool minimized = false;
    bool maximized = false;
    bool closing = false; // NEW: mark requested-close windows
    std::string lastPrinted;
};

std::map<zwlr_foreign_toplevel_handle_v1*, WindowInfo> windows;
std::string activateTitle;
std::string closeTitle;

// ----------------- Hyprland helper -----------------
void switch_to_window_workspace(const std::string &title) {
    QProcess proc;
    proc.start("hyprctl", QStringList() << "-j" << "clients");
    proc.waitForFinished();
    QByteArray output = proc.readAllStandardOutput();

    auto jsonDoc = QJsonDocument::fromJson(output);
    if (!jsonDoc.isArray()) return;

    QJsonArray clients = jsonDoc.array();
    for (const auto &v : clients) {
        auto obj = v.toObject();
        QString winTitle = obj["title"].toString();
        if (winTitle.toStdString() == title) {
            QString workspace = obj["workspace"].toString();
            QString address = obj["address"].toString(); // use address, not id

            // Switch to workspace
            QProcess::execute("hyprctl", QStringList() << "dispatch" << "workspace" << workspace);

            QThread::msleep(50); // wait a bit

            // Focus the window by address
            QProcess::execute("hyprctl", QStringList() << "dispatch" << "focuswindow" << ("address:" + address));

            break;
        }
    }
}


// ----------------- Window and INI handling -----------------
void print_window(zwlr_foreign_toplevel_handle_v1* handle)
{
    auto& win = windows[handle];
    std::string current = "Window: \"" + win.title + "\""
    + " (app_id: " + win.app_id + ")"
    + " [focused=" + std::to_string(win.focused)
    + " minimized=" + std::to_string(win.minimized)
    + " maximized=" + std::to_string(win.maximized)
    + " closing=" + std::to_string(win.closing)
    + "]";
if (current != win.lastPrinted) {
    std::cout << current << std::endl;
    win.lastPrinted = current;
}
}

void write_all_windows_to_ini()
{
    QString path = QDir::homePath() + "/.config/hexlauncher/windows.ini";
    QSettings settings(path, QSettings::IniFormat);
    settings.clear();

    int index = 0;
    for (auto& [handle, win] : windows) {
        // Skip ghost/invalid windows
        if (win.title.empty() || win.app_id.empty())
            continue;

        settings.beginGroup(QString::number(index++));
        settings.setValue("Title", QString::fromStdString(win.title));
        settings.setValue("AppID", QString::fromStdString(win.app_id));
        settings.setValue("Focused", win.focused);
        settings.setValue("Minimized", win.minimized);
        settings.setValue("Maximized", win.maximized);
        settings.endGroup();
    }

    settings.sync();
}


// ----------------- Wayland toplevel listeners -----------------
static void handle_title(void*, zwlr_foreign_toplevel_handle_v1* handle, const char* title)
{
    windows[handle].title = title ? title : "(null)";
}

static void handle_app_id(void*, zwlr_foreign_toplevel_handle_v1* handle, const char* app_id)
{
    windows[handle].app_id = app_id ? app_id : "(null)";
}

static void handle_state(void*, zwlr_foreign_toplevel_handle_v1* handle, struct wl_array* state)
{
    windows[handle].focused = false;
    windows[handle].minimized = false;
    windows[handle].maximized = false;

    uint32_t* s;
    char* end = (char*)state->data + state->size;
    for (char* ptr = (char*)state->data; ptr < end; ptr += sizeof(uint32_t)) {
        s = (uint32_t*)ptr;
        switch (*s) {
            case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_ACTIVATED:
                windows[handle].focused = true;
                break;
            case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MINIMIZED:
                windows[handle].minimized = true;
                break;
            case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MAXIMIZED:
                windows[handle].maximized = true;
                break;
        }
    }
}

static void handle_done(void*, zwlr_foreign_toplevel_handle_v1* handle)
{
    print_window(handle);

    auto& win = windows[handle];

    // If activate requested for this title, do workspace switch + activate
    if (!activateTitle.empty() && win.title == activateTitle) {
        // --- Hyprland workspace switch ---
        switch_to_window_workspace(win.title);

        // Now also activate via Wayland (non-hyprland fallback)
        if (seat) {
            zwlr_foreign_toplevel_handle_v1_activate(handle, seat);
            wl_display_flush(display);
        }
        activateTitle.clear();
    }

    // If a close was requested for this title, mark it closing and request close.
    if (!closeTitle.empty() && win.title == closeTitle) {
        // mark as closing so INI won't include it
        win.closing = true;
        zwlr_foreign_toplevel_handle_v1_close(handle);
        wl_display_flush(display);

        // keep program alive so we can get handle_closed
        // clear the closeTitle so we don't repeatedly send close
        closeTitle.clear();
    }

    // Only write INI for normal updates (skip if this window is marked closing)
    // Note: write_all_windows_to_ini skips closing windows anyway, but avoid extra writes here
    write_all_windows_to_ini();

    if (exit_after_first_dump) {
        // If we are doing a close operation, we purposely keep running until closed.
        // Otherwise, exit as before.
        running = false;
        wl_display_flush(display);
    }
}

static void handle_closed(void*, zwlr_foreign_toplevel_handle_v1* handle)
{
    auto it = windows.find(handle);
    if (it != windows.end()) {
        std::cout << "Window closed: \"" << it->second.title << "\"" << std::endl;

        running = false;  // Stop regardless of which window closed

        windows.erase(it);
        write_all_windows_to_ini();
    } else {
        std::cout << "Window closed: unknown handle" << std::endl;
    }
}


static void handle_parent(void*, zwlr_foreign_toplevel_handle_v1*, zwlr_foreign_toplevel_handle_v1*) { }

static const zwlr_foreign_toplevel_handle_v1_listener toplevel_handle_listener = {
    .title = handle_title,
    .app_id = handle_app_id,
    .output_enter = nullptr,
    .output_leave = nullptr,
    .state = handle_state,
    .done = handle_done,
    .closed = handle_closed,
    .parent = handle_parent
};

static void manager_handle_toplevel(void*, zwlr_foreign_toplevel_manager_v1*,
                                    zwlr_foreign_toplevel_handle_v1* handle)
{
    // Add listener and ensure WindowInfo exists
    windows.emplace(handle, WindowInfo());
    zwlr_foreign_toplevel_handle_v1_add_listener(handle, &toplevel_handle_listener, nullptr);
}

static void manager_handle_finished(void*, zwlr_foreign_toplevel_manager_v1*) { }

static const zwlr_foreign_toplevel_manager_v1_listener manager_listener = {
    .toplevel = manager_handle_toplevel,
    .finished = manager_handle_finished
};

static void handle_global(void*, wl_registry* registry, uint32_t name,
                          const char* interface, uint32_t version)
{
    if (strcmp(interface, zwlr_foreign_toplevel_manager_v1_interface.name) == 0) {
        toplevel_manager = static_cast<zwlr_foreign_toplevel_manager_v1*>(
            wl_registry_bind(registry, name, &zwlr_foreign_toplevel_manager_v1_interface, 3));
    } else if (strcmp(interface, "wl_seat") == 0) {
        seat = static_cast<wl_seat*>(wl_registry_bind(registry, name, &wl_seat_interface, 1));
    }
}

static void handle_global_remove(void*, wl_registry*, uint32_t) { }

static const wl_registry_listener registry_listener = {
    .global = handle_global,
    .global_remove = handle_global_remove
};

int main(int argc, char** argv)
{
    if (argc == 3) {
        std::string arg1 = argv[1];
        if (arg1 == "--activate") {
            activateTitle = argv[2];
        } else if (arg1 == "--close") {
            closeTitle = argv[2];
            // keep the program alive to wait for the compositor to emit closed
            exit_after_first_dump = false;
        }
    }

    display = wl_display_connect(nullptr);
    if (!display) {
        std::cerr << "Failed to connect to Wayland display." << std::endl;
        return 1;
    }

    registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, nullptr);
    wl_display_roundtrip(display);

    if (!toplevel_manager) {
        std::cerr << "Compositor does not support zwlr_foreign_toplevel_manager_v1" << std::endl;
        wl_display_disconnect(display);
        return 1;
    }

    zwlr_foreign_toplevel_manager_v1_add_listener(toplevel_manager, &manager_listener, nullptr);
    // ensure we receive initial events
    wl_display_roundtrip(display);

    // if there are no windows, still write an empty INI
    if (windows.empty()) {
        write_all_windows_to_ini();
        if (exit_after_first_dump) {
            wl_display_disconnect(display);
            return 0;
        }
    }

    // main event loop - keep running until windows closed (if close requested)
    while (running && wl_display_dispatch(display) != -1) { }

    // flush/roundtrip once more before exit
    wl_display_flush(display);
    wl_display_roundtrip(display);
    write_all_windows_to_ini();
    wl_display_disconnect(display);
    return 0;
}
