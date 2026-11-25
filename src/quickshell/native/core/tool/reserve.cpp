// anserin-core reserve: holds pure-CPU 1x1 transparent Wayland layer-shell exclusion zones on screen edges
// (Hyprland, Niri, Sway) without Qt/OpenGL/Mesa contexts and without touching monitor scale/mode config.
// Driven over stdin by ScreenBorder.qml:
//   set <outputName> <top> <bottom> <left> <right>
// Dies automatically with its parent (becomeWatcher + stdin EOF), so the compositor restores 0px margins immediately.
#include "common.h"

#include <wayland-client.h>
#define namespace wl_namespace
#include "wlr-layer-shell-unstable-v1-client-protocol.h"
#undef namespace

#include <array>
#include <cerrno>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <map>
#include <memory>
#include <poll.h>
#include <sstream>
#include <string>
#include <sys/mman.h>
#include <unistd.h>
#include <vector>

namespace core {
namespace {

volatile sig_atomic_t gStop = 0;
void onSignal(int) { gStop = 1; }

constexpr const char *kEdgeNames[4] = { "top", "bottom", "left", "right" };
constexpr uint32_t kEdgeAnchors[4] = {
    ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP,
    ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM,
    ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT,
    ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT,
};

struct ReserveApp;

struct EdgeSlot {
    ReserveApp *app = nullptr;
    wl_surface *surface = nullptr;
    zwlr_layer_surface_v1 *layerSurface = nullptr;
    int zone = 0;
    bool configured = false;

    void destroy() {
        if (layerSurface) {
            zwlr_layer_surface_v1_destroy(layerSurface);
            layerSurface = nullptr;
        }
        if (surface) {
            wl_surface_destroy(surface);
            surface = nullptr;
        }
        zone = 0;
        configured = false;
    }
    ~EdgeSlot() { destroy(); }
};

struct OutputEntry {
    ReserveApp *app = nullptr;
    uint32_t globalName = 0;
    wl_output *output = nullptr;
    std::string name;
    std::array<EdgeSlot, 4> edges;

    ~OutputEntry() {
        for (auto &slot : edges) slot.destroy();
        if (output) {
            wl_output_destroy(output);
            output = nullptr;
        }
    }
};

struct ReserveApp {
    wl_display *display = nullptr;
    wl_registry *registry = nullptr;
    wl_compositor *compositor = nullptr;
    wl_shm *shm = nullptr;
    zwlr_layer_shell_v1 *layerShell = nullptr;
    wl_buffer *pixelBuf = nullptr;
    wl_shm_pool *pixelPool = nullptr;
    void *pixelData = MAP_FAILED;

    std::vector<std::unique_ptr<OutputEntry>> outputs;
    std::map<std::string, std::array<int, 4>> desired; // outputName -> {top, bottom, left, right}

    ~ReserveApp() {
        outputs.clear();
        if (pixelBuf) wl_buffer_destroy(pixelBuf);
        if (pixelPool) wl_shm_pool_destroy(pixelPool);
        if (pixelData != MAP_FAILED) munmap(pixelData, 4);
        if (layerShell) zwlr_layer_shell_v1_destroy(layerShell);
        if (shm) wl_shm_destroy(shm);
        if (compositor) wl_compositor_destroy(compositor);
        if (registry) wl_registry_destroy(registry);
        if (display) wl_display_disconnect(display);
    }

    bool ensurePixelBuffer() {
        if (pixelBuf) return true;
        if (!shm) return false;
        const int fd = memfd_create("anserin-reserve-1x1", MFD_CLOEXEC);
        if (fd < 0) return false;
        if (ftruncate(fd, 4) != 0) { close(fd); return false; }
        pixelData = mmap(nullptr, 4, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        if (pixelData == MAP_FAILED) { close(fd); return false; }
        std::memset(pixelData, 0, 4); // 1x1 fully transparent ARGB8888 pixel
        pixelPool = wl_shm_create_pool(shm, fd, 4);
        close(fd);
        if (!pixelPool) return false;
        pixelBuf = wl_shm_pool_create_buffer(pixelPool, 0, 1, 1, 4, WL_SHM_FORMAT_ARGB8888);
        return pixelBuf != nullptr;
    }

    void syncOutput(OutputEntry &out) {
        if (out.name.empty() || !compositor || !layerShell || !ensurePixelBuffer()) return;
        const auto it = desired.find(out.name);
        const std::array<int, 4> zones = (it != desired.end()) ? it->second : std::array<int, 4>{0, 0, 0, 0};

        for (int e = 0; e < 4; ++e) {
            EdgeSlot &slot = out.edges[size_t(e)];
            const int z = zones[size_t(e)] > 0 ? zones[size_t(e)] : 0;
            if (z == 0) {
                slot.destroy();
                continue;
            }
            if (!slot.layerSurface) {
                slot.app = this;
                slot.surface = wl_compositor_create_surface(compositor);
                if (!slot.surface) continue;
                wl_region *emptyInput = wl_compositor_create_region(compositor);
                wl_surface_set_input_region(slot.surface, emptyInput);
                wl_region_destroy(emptyInput);

                const std::string ns = std::string("anserin-border-exclusion-") + kEdgeNames[e];
                slot.layerSurface = zwlr_layer_shell_v1_get_layer_surface(
                    layerShell, slot.surface, out.output, ZWLR_LAYER_SHELL_V1_LAYER_TOP, ns.c_str());
                if (!slot.layerSurface) { slot.destroy(); continue; }
                zwlr_layer_surface_v1_add_listener(slot.layerSurface, &kLayerSurfaceListener, &slot);
                zwlr_layer_surface_v1_set_size(slot.layerSurface, 1, 1);
                zwlr_layer_surface_v1_set_anchor(slot.layerSurface, kEdgeAnchors[e]);
                zwlr_layer_surface_v1_set_exclusive_zone(slot.layerSurface, z);
                zwlr_layer_surface_v1_set_keyboard_interactivity(slot.layerSurface, 0);
                slot.zone = z;
                slot.configured = false;
                wl_surface_commit(slot.surface);
            } else if (slot.zone != z) {
                slot.zone = z;
                zwlr_layer_surface_v1_set_exclusive_zone(slot.layerSurface, z);
                wl_surface_commit(slot.surface);
            }
        }
    }

    void syncAll() {
        for (auto &out : outputs) syncOutput(*out);
    }

    void handleLine(const std::string &line) {
        std::istringstream iss(line);
        std::string cmd, mon;
        int t = 0, b = 0, l = 0, r = 0;
        if (!(iss >> cmd)) return;
        if (cmd == "quit") { gStop = 1; return; }
        if (cmd == "set" && (iss >> mon >> t >> b >> l >> r)) {
            desired[mon] = { t, b, l, r };
            for (auto &out : outputs) {
                if (out->name == mon) syncOutput(*out);
            }
        }
    }

    static void onLayerConfigure(void *data, zwlr_layer_surface_v1 *ls, uint32_t serial, uint32_t, uint32_t) {
        auto *slot = static_cast<EdgeSlot *>(data);
        zwlr_layer_surface_v1_ack_configure(ls, serial);
        slot->configured = true;
        if (slot->surface && slot->app && slot->app->pixelBuf) {
            wl_surface_attach(slot->surface, slot->app->pixelBuf, 0, 0);
            wl_surface_damage(slot->surface, 0, 0, 1, 1);
            wl_surface_commit(slot->surface);
        }
    }
    static void onLayerClosed(void *data, zwlr_layer_surface_v1 *) {
        static_cast<EdgeSlot *>(data)->destroy();
    }
    static constexpr zwlr_layer_surface_v1_listener kLayerSurfaceListener = {
        onLayerConfigure, onLayerClosed
    };

    static void onOutGeom(void *, wl_output *, int32_t, int32_t, int32_t, int32_t, int32_t, const char *, const char *, int32_t) {}
    static void onOutMode(void *, wl_output *, uint32_t, int32_t, int32_t, int32_t) {}
    static void onOutDone(void *data, wl_output *) {
        auto *out = static_cast<OutputEntry *>(data);
        if (out->app) out->app->syncOutput(*out);
    }
    static void onOutScale(void *, wl_output *, int32_t) {}
    static void onOutName(void *data, wl_output *, const char *name) {
        auto *out = static_cast<OutputEntry *>(data);
        out->name = name ? name : "";
        if (out->app) out->app->syncOutput(*out);
    }
    static void onOutDesc(void *, wl_output *, const char *) {}
    static constexpr wl_output_listener kOutputListener = {
        onOutGeom, onOutMode, onOutDone, onOutScale, onOutName, onOutDesc
    };

    static void onGlobal(void *data, wl_registry *reg, uint32_t name, const char *iface, uint32_t ver) {
        auto *app = static_cast<ReserveApp *>(data);
        if (std::strcmp(iface, wl_compositor_interface.name) == 0) {
            app->compositor = static_cast<wl_compositor *>(wl_registry_bind(reg, name, &wl_compositor_interface, ver < 4 ? ver : 4));
        } else if (std::strcmp(iface, wl_shm_interface.name) == 0) {
            app->shm = static_cast<wl_shm *>(wl_registry_bind(reg, name, &wl_shm_interface, 1));
        } else if (std::strcmp(iface, zwlr_layer_shell_v1_interface.name) == 0) {
            app->layerShell = static_cast<zwlr_layer_shell_v1 *>(wl_registry_bind(reg, name, &zwlr_layer_shell_v1_interface, 1));
        } else if (std::strcmp(iface, wl_output_interface.name) == 0) {
            auto out = std::make_unique<OutputEntry>();
            out->app = app;
            out->globalName = name;
            out->output = static_cast<wl_output *>(wl_registry_bind(reg, name, &wl_output_interface, ver < 4 ? ver : 4));
            wl_output_add_listener(out->output, &kOutputListener, out.get());
            app->outputs.push_back(std::move(out));
        }
    }
    static void onGlobalRemove(void *data, wl_registry *, uint32_t name) {
        auto *app = static_cast<ReserveApp *>(data);
        for (auto it = app->outputs.begin(); it != app->outputs.end(); ++it) {
            if ((*it)->globalName == name) {
                app->outputs.erase(it);
                break;
            }
        }
    }
    static constexpr wl_registry_listener kRegistryListener = { onGlobal, onGlobalRemove };
};

} // namespace

int reserveCommand(int, char **)
{
    becomeWatcher();
    std::signal(SIGTERM, onSignal);
    std::signal(SIGINT, onSignal);
    std::signal(SIGHUP, onSignal);

    ReserveApp app;
    app.display = wl_display_connect(nullptr);
    if (!app.display) {
        std::fprintf(stderr, "anserin-core reserve: cannot connect to Wayland display\n");
        return 1;
    }
    app.registry = wl_display_get_registry(app.display);
    wl_registry_add_listener(app.registry, &ReserveApp::kRegistryListener, &app);
    wl_display_roundtrip(app.display);
    wl_display_roundtrip(app.display);

    if (!app.compositor || !app.shm || !app.layerShell) {
        std::fprintf(stderr, "anserin-core reserve: compositor lacks wlr-layer-shell or wl_shm\n");
        return 1;
    }

    const int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    if (flags >= 0) fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);

    const int wlFd = wl_display_get_fd(app.display);
    std::string pending;

    while (!gStop) {
        while (wl_display_prepare_read(app.display) != 0) {
            if (wl_display_dispatch_pending(app.display) < 0) { gStop = 1; break; }
        }
        if (gStop) { wl_display_cancel_read(app.display); break; }
        if (wl_display_flush(app.display) < 0 && errno != EAGAIN) {
            wl_display_cancel_read(app.display);
            break;
        }

        pollfd pfds[2] = {
            { wlFd, POLLIN, 0 },
            { STDIN_FILENO, POLLIN, 0 },
        };
        const int rc = poll(pfds, 2, -1);
        if (rc < 0) {
            wl_display_cancel_read(app.display);
            if (errno == EINTR) continue;
            break;
        }

        if (pfds[0].revents & POLLIN) {
            if (wl_display_read_events(app.display) < 0) break;
            if (wl_display_dispatch_pending(app.display) < 0) break;
        } else {
            wl_display_cancel_read(app.display);
            if (pfds[0].revents & (POLLERR | POLLHUP)) break;
        }

        if (pfds[1].revents & (POLLIN | POLLHUP)) {
            char buf[512];
            for (;;) {
                const ssize_t n = read(STDIN_FILENO, buf, sizeof buf);
                if (n > 0) {
                    pending.append(buf, size_t(n));
                    size_t nl;
                    while ((nl = pending.find('\n')) != std::string::npos) {
                        std::string line = pending.substr(0, nl);
                        pending.erase(0, nl + 1);
                        app.handleLine(line);
                    }
                } else if (n == 0) {
                    gStop = 1; // parent closed pipe -> exit cleanly so compositor clears all exclusive zones
                    break;
                } else {
                    if (errno == EAGAIN || errno == EWOULDBLOCK) break;
                    gStop = 1;
                    break;
                }
            }
            wl_display_flush(app.display);
        }
    }

    return 0;
}

} // namespace core
