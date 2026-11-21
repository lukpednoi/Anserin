// anserin-core gamma: Night light. A small daemon holds the screens' colour ramps through the
// wlr-gamma-control protocol (Hyprland, Sway, river...) and is driven over a socket in $XDG_RUNTIME_DIR/anserin,
// with the same commands scripts/gamma.sh used with serpantinum-gamma:
//   start | quit | status [-o OUT] | set [-o OUT] [--temperature K] [--brightness 0-1] [--gamma G] [--inverted on|off]
//   reset [-o OUT] | auto on|off [-o OUT] [--day K] [--night K] | location LAT LON | location clear
//   fallback DAY NIGHT (HH:MM, when the fades to day and to night start without a location)
//   probe (exit 0 when the compositor offers gamma control; blue_light_filter.sh asks before handing over)
// Without -o a command changes every output, including outputs connected later. Quitting hands the ramps back
// to the compositor, which restores normal colours.
#include "common.h"

#include "wlr-gamma-control-unstable-v1-client-protocol.h"
#include <wayland-client.h>

#include <algorithm>
#include <cerrno>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <fcntl.h>
#include <map>
#include <memory>
#include <poll.h>
#include <sstream>
#include <string>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

namespace core {
namespace {

constexpr char kSep = '\x1f';   // between arguments on the socket

std::string socketPath()
{
    const char *run = std::getenv("XDG_RUNTIME_DIR");
    return std::string(run ? run : "/tmp") + "/anserin/gamma.sock";
}

// ---------- colour ----------

struct Look {
    double temperature = 6500, brightness = 1, gamma = 1;
    bool inverted = false;
    bool automatic = false;
    double day = 6500, night = 4000;
};

// white point of a black body at kelvin, normalised so 6500 K is neutral (Tanner Helland's fit)
void whitePoint(double kelvin, double rgb[3])
{
    auto raw = [](double k, double out[3]) {
        const double t = k / 100.0;
        double r, g, b;
        if (t <= 66) { r = 255; g = 99.4708025861 * std::log(t) - 161.1195681661; }
        else { r = 329.698727446 * std::pow(t - 60, -0.1332047592); g = 288.1221695283 * std::pow(t - 60, -0.0755148492); }
        if (t >= 66) b = 255;
        else if (t <= 19) b = 0;
        else b = 138.5177312231 * std::log(t - 10) - 305.0447927307;
        out[0] = std::clamp(r, 0.0, 255.0) / 255; out[1] = std::clamp(g, 0.0, 255.0) / 255; out[2] = std::clamp(b, 0.0, 255.0) / 255;
    };
    double n[3];
    raw(6500, n);
    raw(std::clamp(kelvin, 1000.0, 10000.0), rgb);
    for (int i = 0; i < 3; ++i) rgb[i] = std::min(1.0, rgb[i] / n[i]);
}

// ---------- the day and night schedule ----------

struct Schedule {
    bool hasLocation = false;
    double lat = 0, lon = 0;
    int dayStartMin = 6 * 60 + 30, nightStartMin = 19 * 60;   // fallback, minutes after local midnight
};

// today's sunrise and sunset in local minutes (NOAA's simplified equations); false at polar day / night
bool sunTimes(double lat, double lon, double &rise, double &set)
{
    std::time_t now = std::time(nullptr);
    std::tm local{};
    localtime_r(&now, &local);
    const int doy = local.tm_yday + 1;
    const double g = 2 * M_PI / 365.0 * (doy - 1 + 0.5);
    const double eq = 229.18 * (0.000075 + 0.001868 * std::cos(g) - 0.032077 * std::sin(g)
                      - 0.014615 * std::cos(2 * g) - 0.040849 * std::sin(2 * g));
    const double decl = 0.006918 - 0.399912 * std::cos(g) + 0.070257 * std::sin(g) - 0.006758 * std::cos(2 * g)
                        + 0.000907 * std::sin(2 * g) - 0.002697 * std::cos(3 * g) + 0.00148 * std::sin(3 * g);
    const double la = lat * M_PI / 180;
    const double c = std::cos(90.833 * M_PI / 180) / (std::cos(la) * std::cos(decl)) - std::tan(la) * std::tan(decl);
    if (c < -1 || c > 1) return false;
    const double ha = std::acos(c) * 180 / M_PI;
    const double tz = local.tm_gmtoff / 60.0;
    rise = 720 - 4 * (lon + ha) - eq + tz;
    set = 720 - 4 * (lon - ha) - eq + tz;
    return true;
}

// 0 = full day, 1 = full night, in between while fading (30 minutes)
double nightAmount(const Schedule &s)
{
    std::time_t now = std::time(nullptr);
    std::tm local{};
    localtime_r(&now, &local);
    const double m = local.tm_hour * 60 + local.tm_min + local.tm_sec / 60.0;
    double dayStart = s.dayStartMin, nightStart = s.nightStartMin;
    if (s.hasLocation) {
        double rise, set;
        if (sunTimes(s.lat, s.lon, rise, set)) { dayStart = rise - 30; nightStart = set; }
    }
    const double fade = 30;
    auto ramp = [&](double t0) { return std::clamp((m - t0) / fade, 0.0, 1.0); };
    if (m >= dayStart && m < nightStart) return 1.0 - ramp(dayStart);           // morning fade to day, then day
    return m >= nightStart ? ramp(nightStart) : 1.0;                             // evening fade, then night
}

// ---------- the daemon ----------

struct Output {
    uint32_t globalName = 0;
    wl_output *wl = nullptr;
    zwlr_gamma_control_v1 *control = nullptr;
    std::string name;
    uint32_t size = 0;
    bool failed = false;
    double appliedTemp = -1, appliedBrightness = -1, appliedGamma = -1;
    int appliedInverted = -1;
};

struct Daemon {
    wl_display *display = nullptr;
    wl_registry *registry = nullptr;
    zwlr_gamma_control_manager_v1 *manager = nullptr;
    std::map<uint32_t, std::unique_ptr<Output>> outputs;
    Look everyone;                                  // used by outputs without their own look
    std::map<std::string, Look> perOutput;
    Schedule schedule;
    bool quit = false;

    const Look &lookFor(const Output &o) const
    {
        auto it = perOutput.find(o.name);
        return it != perOutput.end() ? it->second : everyone;
    }
    double effectiveTemp(const Look &l) const
    {
        if (!l.automatic) return l.temperature;
        const double t = nightAmount(schedule);
        return l.day + (l.night - l.day) * t;
    }
    void apply(Output &o, bool force = false);
    void applyAll(bool force = false) { for (auto &kv : outputs) apply(*kv.second, force); }
    void attachControl(Output &o);
};

void Daemon::apply(Output &o, bool force)
{
    if (!o.control || o.size == 0 || o.failed) return;
    const Look &l = lookFor(o);
    const double temp = std::round(effectiveTemp(l));
    if (!force && temp == o.appliedTemp && l.brightness == o.appliedBrightness && l.gamma == o.appliedGamma &&
        int(l.inverted) == o.appliedInverted) return;
    const size_t bytes = size_t(o.size) * 3 * sizeof(uint16_t);
    const int fd = memfd_create("anserin-gamma", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, off_t(bytes)) < 0) { if (fd >= 0) close(fd); return; }
    auto *table = static_cast<uint16_t *>(mmap(nullptr, bytes, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0));
    if (table == MAP_FAILED) { close(fd); return; }
    double wp[3];
    whitePoint(temp, wp);
    for (int c = 0; c < 3; ++c) {
        for (uint32_t i = 0; i < o.size; ++i) {
            double v = double(i) / double(o.size - 1);
            v = std::pow(v, 1.0 / std::max(0.1, l.gamma)) * l.brightness * wp[c];
            if (l.inverted) v = 1.0 - v;
            table[size_t(c) * o.size + i] = uint16_t(std::lround(std::clamp(v, 0.0, 1.0) * 65535.0));
        }
    }
    munmap(table, bytes);
    lseek(fd, 0, SEEK_SET);
    zwlr_gamma_control_v1_set_gamma(o.control, fd);
    close(fd);
    o.appliedTemp = temp; o.appliedBrightness = l.brightness; o.appliedGamma = l.gamma; o.appliedInverted = l.inverted;
}

const zwlr_gamma_control_v1_listener kControlListener = {
    [](void *data, zwlr_gamma_control_v1 *, uint32_t size) {
        auto *o = static_cast<Output *>(data);
        o->size = size;
        o->appliedTemp = -1;   // apply on the next pass
    },
    [](void *data, zwlr_gamma_control_v1 *) {
        auto *o = static_cast<Output *>(data);   // another program holds this output's colours
        o->failed = true;
    },
};

void Daemon::attachControl(Output &o)
{
    if (!manager || o.control || !o.wl) return;
    o.control = zwlr_gamma_control_manager_v1_get_gamma_control(manager, o.wl);
    zwlr_gamma_control_v1_add_listener(o.control, &kControlListener, &o);
}

const wl_output_listener kOutputListener = {
    [](void *, wl_output *, int32_t, int32_t, int32_t, int32_t, int32_t, const char *, const char *, int32_t) {},
    [](void *, wl_output *, uint32_t, int32_t, int32_t, int32_t) {},
    [](void *, wl_output *) {},
    [](void *, wl_output *, int32_t) {},
    [](void *data, wl_output *, const char *name) { static_cast<Output *>(data)->name = name; },
    [](void *, wl_output *, const char *) {},
};

const wl_registry_listener kRegistryListener = {
    [](void *data, wl_registry *reg, uint32_t name, const char *iface, uint32_t version) {
        auto *d = static_cast<Daemon *>(data);
        if (std::strcmp(iface, zwlr_gamma_control_manager_v1_interface.name) == 0) {
            d->manager = static_cast<zwlr_gamma_control_manager_v1 *>(
                wl_registry_bind(reg, name, &zwlr_gamma_control_manager_v1_interface, 1));
            for (auto &kv : d->outputs) d->attachControl(*kv.second);
        } else if (std::strcmp(iface, wl_output_interface.name) == 0) {
            auto o = std::make_unique<Output>();
            o->globalName = name;
            o->wl = static_cast<wl_output *>(wl_registry_bind(reg, name, &wl_output_interface, std::min(version, 4u)));
            wl_output_add_listener(o->wl, &kOutputListener, o.get());
            d->attachControl(*o);
            d->outputs[name] = std::move(o);
        }
    },
    [](void *data, wl_registry *, uint32_t name) {
        auto *d = static_cast<Daemon *>(data);
        auto it = d->outputs.find(name);
        if (it == d->outputs.end()) return;
        if (it->second->control) zwlr_gamma_control_v1_destroy(it->second->control);
        if (it->second->wl) wl_output_release(it->second->wl);
        d->outputs.erase(it);
    },
};

bool parseTime(const std::string &s, int &minutes)
{
    int h, m;
    if (std::sscanf(s.c_str(), "%d:%d", &h, &m) != 2 || h < 0 || h > 23 || m < 0 || m > 59) return false;
    minutes = h * 60 + m;
    return true;
}

std::string handle(Daemon &d, const std::vector<std::string> &a)
{
    if (a.empty()) return "error no command";
    const std::string cmd = a[0];
    std::string output;
    std::map<std::string, std::string> opt;
    std::vector<std::string> rest;
    for (size_t i = 1; i < a.size(); ++i) {
        if ((a[i] == "-o" || a[i] == "--output") && i + 1 < a.size()) output = a[++i];
        else if (a[i].rfind("--", 0) == 0 && i + 1 < a.size()) { opt[a[i]] = a[i + 1]; ++i; }
        else rest.push_back(a[i]);
    }
    auto target = [&]() -> Look & {
        if (output.empty()) return d.everyone;
        auto it = d.perOutput.find(output);
        if (it == d.perOutput.end()) it = d.perOutput.emplace(output, d.everyone).first;
        return it->second;
    };
    if (cmd == "quit") { d.quit = true; return "ok"; }
    if (cmd == "status") {
        std::ostringstream ss;
        ss << "running";
        for (auto &kv : d.outputs) {
            const Output &o = *kv.second;
            if (!output.empty() && o.name != output) continue;
            const Look &l = d.lookFor(o);
            ss << "\n" << (o.name.empty() ? "output" : o.name) << ": " << int(std::round(d.effectiveTemp(l))) << "K"
               << " brightness " << l.brightness << " gamma " << l.gamma << (l.inverted ? " inverted" : "")
               << (l.automatic ? " auto" : " manual") << (o.failed ? " (held by another program)" : "");
        }
        if (d.schedule.hasLocation) ss << "\nlocation " << d.schedule.lat << " " << d.schedule.lon;
        return ss.str();
    }
    if (cmd == "set") {
        if (!output.empty()) {
            bool known = false;
            for (auto &kv : d.outputs) known = known || kv.second->name == output;
            if (!known) return "error unknown output " + output;
        }
        Look &l = target();
        if (opt.count("--temperature")) { l.temperature = std::clamp(std::atof(opt["--temperature"].c_str()), 1000.0, 10000.0); l.automatic = false; }
        if (opt.count("--brightness")) l.brightness = std::clamp(std::atof(opt["--brightness"].c_str()), 0.1, 1.0);
        if (opt.count("--gamma")) l.gamma = std::clamp(std::atof(opt["--gamma"].c_str()), 0.1, 10.0);
        if (opt.count("--inverted")) l.inverted = opt["--inverted"] == "on";
        if (output.empty()) d.perOutput.clear();
        d.applyAll();
        return "ok";
    }
    if (cmd == "reset") {
        if (output.empty()) { d.everyone = Look(); d.perOutput.clear(); }
        else d.perOutput[output] = Look();
        d.applyAll();
        return "ok";
    }
    if (cmd == "auto") {
        if (rest.empty() || (rest[0] != "on" && rest[0] != "off")) return "error auto on|off";
        Look &l = target();
        l.automatic = rest[0] == "on";
        if (opt.count("--day")) l.day = std::clamp(std::atof(opt["--day"].c_str()), 1000.0, 10000.0);
        if (opt.count("--night")) l.night = std::clamp(std::atof(opt["--night"].c_str()), 1000.0, 10000.0);
        if (!l.automatic) l.temperature = 6500;
        if (output.empty()) d.perOutput.clear();
        d.applyAll();
        return "ok";
    }
    if (cmd == "location") {
        if (!rest.empty() && rest[0] == "clear") { d.schedule.hasLocation = false; d.applyAll(); return "ok"; }
        if (rest.size() < 2) return "error location LAT LON | location clear";
        d.schedule.hasLocation = true;
        d.schedule.lat = std::clamp(std::atof(rest[0].c_str()), -90.0, 90.0);
        d.schedule.lon = std::clamp(std::atof(rest[1].c_str()), -180.0, 180.0);
        d.applyAll();
        return "ok";
    }
    if (cmd == "fallback") {
        int a1, a2;
        if (rest.size() < 2 || !parseTime(rest[0], a1) || !parseTime(rest[1], a2)) return "error fallback HH:MM HH:MM";
        d.schedule.dayStartMin = a1; d.schedule.nightStartMin = a2;
        d.applyAll();
        return "ok";
    }
    return "error unknown command " + cmd;
}

int runDaemon(int readyFd)
{
    const std::string path = socketPath();
    mkdir((path.substr(0, path.rfind('/'))).c_str(), 0700);
    Daemon d;
    d.display = wl_display_connect(nullptr);
    if (!d.display) { std::fprintf(stderr, "anserin-core gamma: no Wayland display\n"); return 1; }
    d.registry = wl_display_get_registry(d.display);
    wl_registry_add_listener(d.registry, &kRegistryListener, &d);
    wl_display_roundtrip(d.display);
    wl_display_roundtrip(d.display);
    if (!d.manager) { std::fprintf(stderr, "anserin-core gamma: the compositor has no gamma control\n"); return 1; }

    const int lfd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    path.copy(addr.sun_path, sizeof addr.sun_path - 1);
    unlink(path.c_str());
    if (bind(lfd, reinterpret_cast<sockaddr *>(&addr), sizeof addr) < 0 || listen(lfd, 8) < 0) {
        std::fprintf(stderr, "anserin-core gamma: cannot listen on %s\n", path.c_str());
        return 1;
    }
    chmod(path.c_str(), 0600);
    if (readyFd >= 0) { (void)!write(readyFd, "1", 1); close(readyFd); }
    d.applyAll(true);

    while (!d.quit) {
        while (wl_display_prepare_read(d.display) != 0) wl_display_dispatch_pending(d.display);
        wl_display_flush(d.display);
        pollfd fds[2] = { { wl_display_get_fd(d.display), POLLIN, 0 }, { lfd, POLLIN, 0 } };
        // while following the schedule, look at the clock every 20 s (fades take 30 minutes); else sleep
        bool anyAuto = d.everyone.automatic;
        for (auto &kv : d.perOutput) anyAuto = anyAuto || kv.second.automatic;
        const int r = poll(fds, 2, anyAuto ? 20000 : -1);
        if (r > 0 && (fds[0].revents & POLLIN)) wl_display_read_events(d.display);
        else wl_display_cancel_read(d.display);
        if (wl_display_dispatch_pending(d.display) < 0) break;   // compositor gone
        if (r > 0 && (fds[0].revents & (POLLHUP | POLLERR))) break;
        if (r > 0 && (fds[1].revents & POLLIN)) {
            const int c = accept4(lfd, nullptr, nullptr, SOCK_CLOEXEC);
            if (c >= 0) {
                timeval tv{2, 0};
                setsockopt(c, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv);
                std::string msg;
                char buf[1024];
                ssize_t n;
                while ((n = read(c, buf, sizeof buf)) > 0) { msg.append(buf, size_t(n)); if (msg.find('\n') != std::string::npos) break; }
                if (!msg.empty() && msg.back() == '\n') msg.pop_back();
                std::vector<std::string> args;
                std::string cur;
                for (char ch : msg) { if (ch == kSep) { args.push_back(cur); cur.clear(); } else cur += ch; }
                if (!cur.empty()) args.push_back(cur);
                const std::string reply = handle(d, args) + "\n";
                (void)!write(c, reply.data(), reply.size());
                close(c);
            }
        }
        d.applyAll();   // new outputs, sizes that arrived, schedule
    }
    for (auto &kv : d.outputs) if (kv.second->control) zwlr_gamma_control_v1_destroy(kv.second->control);
    wl_display_flush(d.display);
    wl_display_disconnect(d.display);
    close(lfd);
    unlink(path.c_str());
    return 0;
}

// sends one command to the daemon; returns its reply, or "" when it is not running
std::string ask(const std::vector<std::string> &args)
{
    const int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    socketPath().copy(addr.sun_path, sizeof addr.sun_path - 1);
    if (connect(fd, reinterpret_cast<sockaddr *>(&addr), sizeof addr) < 0) { close(fd); return {}; }
    std::string msg;
    for (size_t i = 0; i < args.size(); ++i) { if (i) msg += kSep; msg += args[i]; }
    msg += "\n";
    (void)!write(fd, msg.data(), msg.size());
    std::string reply;
    char buf[1024];
    ssize_t n;
    while ((n = read(fd, buf, sizeof buf)) > 0) reply.append(buf, size_t(n));
    close(fd);
    while (!reply.empty() && reply.back() == '\n') reply.pop_back();
    return reply;
}

int startDaemon()
{
    if (!ask({"status"}).empty()) return 0;
    int pipefd[2];
    if (pipe2(pipefd, O_CLOEXEC) < 0) return 1;
    const pid_t pid = fork();
    if (pid < 0) return 1;
    if (pid == 0) {
        close(pipefd[0]);
        if (fork() != 0) _exit(0);              // daemonise: the grandchild lives on, not tied to the caller
        setsid();
        const int null = open("/dev/null", O_RDWR);
        if (null >= 0) { dup2(null, 0); dup2(null, 1); if (null > 2) close(null); }
        _exit(runDaemon(pipefd[1]));
    }
    close(pipefd[1]);
    waitpid(pid, nullptr, 0);
    char c = 0;
    const bool ok = read(pipefd[0], &c, 1) == 1;
    close(pipefd[0]);
    return ok ? 0 : 1;
}

} // namespace

int gammaCommand(int argc, char **argv)
{
    // argv: [gamma, ...]
    std::vector<std::string> args(argv + 1, argv + argc);
    if (args.empty()) { std::fprintf(stderr, "usage: anserin-core gamma start|quit|status|set|reset|auto|location|fallback\n"); return 2; }
    if (args[0] == "start") return startDaemon();
    if (args[0] == "daemon") return runDaemon(-1);   // in the foreground, for testing
    if (args[0] == "probe") {                         // can Night light work here? (the compositor has gamma control)
        wl_display *dpy = wl_display_connect(nullptr);
        if (!dpy) return 1;
        bool found = false;
        static const wl_registry_listener probe = {
            [](void *data, wl_registry *, uint32_t, const char *iface, uint32_t) {
                if (std::strcmp(iface, zwlr_gamma_control_manager_v1_interface.name) == 0) *static_cast<bool *>(data) = true;
            },
            [](void *, wl_registry *, uint32_t) {},
        };
        wl_registry *reg = wl_display_get_registry(dpy);
        wl_registry_add_listener(reg, &probe, &found);
        wl_display_roundtrip(dpy);
        wl_registry_destroy(reg);
        wl_display_disconnect(dpy);
        return found ? 0 : 1;
    }
    const std::string reply = ask(args);
    if (reply.empty()) {
        if (args[0] == "quit") return 0;
        std::fprintf(stderr, "anserin-core gamma: the daemon is not running\n");
        return 1;
    }
    if (reply.rfind("error", 0) == 0) { std::fprintf(stderr, "%s\n", reply.c_str() + 6); return 1; }
    if (reply != "ok") emit(reply);
    return 0;
}

} // namespace core
