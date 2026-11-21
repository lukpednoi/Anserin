// anserin-core monitors: the outputs in use as [{"name","width","height","refreshRate"}], asked from Hyprland
// over its socket (no hyprctl process). Exit 1 when Hyprland is not there, so callers use their own way.
#include "common.h"

#include <cstdlib>
#include <string>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

namespace core {

// one request to Hyprland's command socket, e.g. "j/monitors"; empty when it cannot be reached
std::string hyprRequest(const std::string &request)
{
    const char *run = std::getenv("XDG_RUNTIME_DIR"), *sig = std::getenv("HYPRLAND_INSTANCE_SIGNATURE");
    if (!run || !sig) return {};
    const std::string path = std::string(run) + "/hypr/" + sig + "/.socket.sock";
    const int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) return {};
    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    if (path.size() >= sizeof addr.sun_path) { close(fd); return {}; }
    path.copy(addr.sun_path, path.size());
    std::string out;
    if (connect(fd, reinterpret_cast<sockaddr *>(&addr), sizeof addr) == 0 &&
        write(fd, request.data(), request.size()) == ssize_t(request.size())) {
        char buf[4096];
        ssize_t n;
        while ((n = read(fd, buf, sizeof buf)) > 0) out.append(buf, size_t(n));
    }
    close(fd);
    return out;
}

namespace {
// the value after "key": in a flat JSON object (enough for Hyprland's monitor list)
std::string field(const std::string &obj, const std::string &key)
{
    const auto k = obj.find("\"" + key + "\"");
    if (k == std::string::npos) return {};
    auto p = obj.find(':', k);
    if (p == std::string::npos) return {};
    ++p;
    while (p < obj.size() && obj[p] == ' ') ++p;
    if (p < obj.size() && obj[p] == '"') {
        const auto e = obj.find('"', p + 1);
        return e == std::string::npos ? std::string() : obj.substr(p + 1, e - p - 1);
    }
    auto e = p;
    while (e < obj.size() && (std::isdigit((unsigned char)obj[e]) || obj[e] == '.' || obj[e] == '-')) ++e;
    return obj.substr(p, e - p);
}
} // namespace

int monitorsCommand(int, char **)
{
    const std::string json = hyprRequest("j/monitors");
    if (json.empty() || json[0] != '[') { emit("[]"); return 1; }
    std::string out = "[";
    size_t pos = 0;
    int depth = 0, count = 0;
    size_t start = 0;
    for (size_t i = 0; i < json.size(); ++i) {           // top-level objects of the array
        if (json[i] == '{') { if (depth++ == 0) start = i; }
        else if (json[i] == '}') {
            if (--depth == 0) {
                const std::string obj = json.substr(start, i - start + 1);
                if (field(obj, "disabled") == "true") continue;
                const std::string name = field(obj, "name");
                if (name.empty()) continue;
                if (count++) out += ",";
                out += "{\"name\":" + jsonString(name) + ",\"width\":" + field(obj, "width") +
                       ",\"height\":" + field(obj, "height") + ",\"refreshRate\":" + field(obj, "refreshRate") + "}";
            }
        }
        (void)pos;
    }
    emit(out + "]");
    return 0;
}

} // namespace core
