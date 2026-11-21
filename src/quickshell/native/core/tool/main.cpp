// anserin-core: Anserin's own helper program (replaces serpantinum-core and serpantinum-gamma).
//   sysinfo | watch sysinfo [--interval S]      CPU, memory, temperature, network and disk use (JSON lines)
//   monitors                                    the outputs in use (JSON)
//   locks | watch locks [--changes]             Caps Lock / Num Lock (JSON lines, or "capslock 1" lines)
//   brightness [get|set P|raise|lower|backend]  the backlight in percent;  watch brightness (JSON lines)
//   gamma ...                                   Night light (see gamma.cpp)
// Every watch ends with the program that started it.
#include "common.h"

#include <cstdio>
#include <string>

int main(int argc, char **argv)
{
    using namespace core;
    if (argc < 2) {
        std::fprintf(stderr, "usage: anserin-core sysinfo|monitors|locks|brightness|gamma|watch sysinfo|watch locks|watch brightness\n");
        return 2;
    }
    const std::string cmd = argv[1];
    const std::string sub = argc > 2 ? argv[2] : "";
    if (cmd == "sysinfo") return sysinfoCommand(argc - 1, argv + 1);
    if (cmd == "monitors") return monitorsCommand(argc - 1, argv + 1);
    if (cmd == "locks") return locksCommand(1, argv + 1);
    if (cmd == "brightness") return brightnessCommand(argc - 1, argv + 1);
    if (cmd == "gamma") return gammaCommand(argc - 1, argv + 1);
    if (cmd == "watch" && sub == "sysinfo") return sysinfoCommand(argc - 1, argv + 1);
    if (cmd == "watch" && sub == "locks") return locksCommand(argc - 1, argv + 1);
    if (cmd == "watch" && sub == "brightness") return brightnessCommand(argc - 1, argv + 1);
    if (cmd == "--version") { std::puts("anserin-core 1"); return 0; }
    std::fprintf(stderr, "anserin-core: unknown command %s\n", cmd.c_str());
    return 2;
}
