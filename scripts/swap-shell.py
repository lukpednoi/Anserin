#!/usr/bin/env python3
"""Start or stop Anserin in the existing Hyprland session."""
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent.parent
STABLE = Path.home() / '.local/share/serpantinum/bin/serpantinumd'
STABLE_PID = Path('/tmp/serpantinumd.pid')
SESSION_KEYS = {
    'XDG_RUNTIME_DIR', 'WAYLAND_DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE',
    'XDG_SESSION_ID', 'XDG_SESSION_TYPE', 'XDG_CURRENT_DESKTOP',
    'DBUS_SESSION_BUS_ADDRESS', 'DISPLAY', 'XAUTHORITY',
}


def stable_argv(argv):
    return any(arg.startswith('/') and Path(arg).resolve() == STABLE for arg in argv[:2])


def stable_process():
    try:
        recorded_pid = STABLE_PID.read_text().strip()
    except FileNotFoundError:
        return None
    pid = int(recorded_pid)
    if pid <= 1:
        raise RuntimeError('Invalid Stable PID')
    proc = Path('/proc') / str(pid)
    if proc.stat().st_uid != os.getuid():
        raise RuntimeError('Stable PID belongs to another user')
    argv = proc.joinpath('cmdline').read_bytes().decode().strip('\0').split('\0')
    if not stable_argv(argv):
        raise RuntimeError('Stable PID does not match the installed daemon')
    environment = {}
    for entry in proc.joinpath('environ').read_bytes().split(b'\0'):
        key, _, value = entry.partition(b'=')
        key = key.decode(errors='replace')
        if key in SESSION_KEYS:
            environment[key] = value.decode()
    return pid, environment


def stable_running():
    shell_qml = str(STABLE.parent.parent / 'src/quickshell/Shell.qml')
    for proc in Path('/proc').iterdir():
        if not proc.name.isdecimal():
            continue
        try:
            if proc.stat().st_uid != os.getuid():
                continue
            argv = proc.joinpath('cmdline').read_bytes().decode().strip('\0').split('\0')
        except (OSError, UnicodeError):
            continue
        if stable_argv(argv) or shell_qml in argv:
            return True
    return False


def fork_running(runtime):
    return subprocess.run([
        'bash', '-c',
        'source "$1"; QS_RUN_DIR="$2"; QS_CACHE_DIR="$3"; mo_pid_valid "$QS_RUN_DIR/anserind.pid"',
        'bash', str(ROOT / 'src/scripts/owned-process.sh'), str(runtime / 'anserin'),
        str(Path.home() / '.cache/anserin'),
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def child_environment(session, fork):
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith(('QS_', 'ANSERIN', 'SERPANTINUM'))}
    environment.update(session)
    if fork:
        environment['XDG_CACHE_HOME'] = str(Path.home() / '.cache/anserin')
    return environment


def stop_stable(pid):
    fd = os.pidfd_open(pid)
    try:
        current = stable_process()
        if current is None or current[0] != pid:
            raise RuntimeError('Stable PID changed before stop')
        signal.pidfd_send_signal(fd, signal.SIGTERM)
        poll = select.poll()
        poll.register(fd, select.POLLIN)
        if not poll.poll(10000):
            raise RuntimeError('Stable did not stop within 10 seconds; fork was not started')
    finally:
        os.close(fd)


def launch(daemon, session, fork, run):
    environment = child_environment(session, fork)
    label = 'fork' if fork else 'stable'
    with (run / f'{label}.log').open('a') as log:
        offset = log.tell()
        process = subprocess.Popen([str(daemon), 'start'], env=environment,
                                   cwd=ROOT, stdin=subprocess.DEVNULL, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
    wait_for_log(process, run / f'{label}.log', offset, 'Configuration Loaded')


def wait_for_log(process, path, offset, marker):
    for _ in range(80):
        if process.poll() is not None:
            raise RuntimeError(f'{path.stem} exited; see {path}')
        with path.open(errors='replace') as log:
            log.seek(offset)
            ready = marker in log.read()
        if ready:
            return
        time.sleep(0.25)
    raise RuntimeError(f'{path.stem} did not become ready within 20 seconds; see {path}')


def transition_environment(session):
    environment = child_environment(session, True)
    runtime = Path(session['XDG_RUNTIME_DIR'])
    display = Path(session['WAYLAND_DISPLAY'])
    environment['WAYLAND_DISPLAY'] = str(display if display.is_absolute() else runtime / display)
    environment['XDG_RUNTIME_DIR'] = str(runtime / 'anserin')
    return environment


def transition_ipc(session, method):
    return subprocess.run([
        'quickshell', '-p', str(ROOT / 'src/quickshell/StartupTransition.qml'),
        'ipc', 'call', 'startup-transition', method,
    ], env=transition_environment(session), capture_output=True, text=True, check=True, timeout=3)


def stop_transition(process, session, run):
    if process.poll() is not None:
        return
    try:
        transition_ipc(session, 'finish')
        process.wait(timeout=2)
    except (subprocess.SubprocessError, OSError):
        subprocess.run([
            'bash', '-c',
            'source "$1"; QS_RUN_DIR="$2"; QS_CACHE_DIR="$3"; mo_stop_tree "$QS_RUN_DIR/startup-transition.pid"',
            'bash', str(ROOT / 'src/scripts/owned-process.sh'), str(run),
            str(Path.home() / '.cache/anserin'),
        ], check=True, timeout=5)


def start_transition(session, run):
    path = run / 'startup-transition.log'
    with path.open('a') as log:
        offset = log.tell()
        process = subprocess.Popen([
            'quickshell', '-p', str(ROOT / 'src/quickshell/StartupTransition.qml'),
        ], env=transition_environment(session), cwd=ROOT, stdin=subprocess.DEVNULL,
            stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        subprocess.run([
            'bash', '-c', 'source "$1"; mo_pid_write "$2" "$3"',
            'bash', str(ROOT / 'src/scripts/owned-process.sh'),
            str(run / 'startup-transition.pid'), str(process.pid),
        ], check=True, timeout=3)
        wait_for_log(process, path, offset, 'ANSERIN_STARTUP_BLACK')
    except Exception:
        stop_transition(process, session, run)
        raise
    return process


def startup_lock(session):
    command = ['quickshell', '-p', str(ROOT / 'src/quickshell/Shell.qml'), 'ipc', 'call', 'lock']
    environment = child_environment(session, True)
    subprocess.run(command + ['startup'], env=environment, check=True, capture_output=True, timeout=3)
    for _ in range(40):
        result = subprocess.run(command + ['startupReady'], env=environment, check=True,
                                capture_output=True, text=True, timeout=3)
        if result.stdout.strip() == 'true':
            return
        time.sleep(0.1)
    # Keep the authentication process alive even if readiness confirmation fails.
    raise RuntimeError('anserin started, but its lock was not confirmed; shell left running')


def stop_fork(session):
    subprocess.run([str(ROOT / 'bin/anserind'), 'stop'],
                   env=child_environment(session, True), check=True, timeout=30)


def current_session(runtime):
    session = {key: value for key, value in os.environ.items() if key in SESSION_KEYS}
    display = Path(session.get('WAYLAND_DISPLAY', ''))
    if not display.is_absolute():
        display = runtime / display
    signature = session.get('HYPRLAND_INSTANCE_SIGNATURE', '')
    if not display.is_socket() or not signature or not (runtime / 'hypr' / signature / '.socket.sock').is_socket():
        raise RuntimeError('Run swap-in from a terminal in the current Hyprland session')
    return session


def login():
    """Open the fork behind the black fade at login and land on its lock screen, like swap-in."""
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    if fork_running(runtime):
        print('login: anserin is already running')
        return
    if stable_running():
        raise RuntimeError('Stable is already running; anserin was not started')
    session = current_session(runtime)
    run = runtime / 'anserin'
    run.mkdir(mode=0o700, parents=True, exist_ok=True)
    transition = start_transition(session, run)
    try:
        try:
            launch(ROOT / 'bin/anserind', session, True, run)
        except Exception:
            stop_fork(session)
            raise
        startup_lock(session)
    finally:
        stop_transition(transition, session, run)
    print('login: fork configuration loaded; locked')


def main(action):
    os.umask(0o077)
    if action == 'login':
        login()
        return
    if action == 'swap-out':
        session = {key: value for key, value in os.environ.items() if key in SESSION_KEYS}
        stop_fork(session)
        print('swap-out: anserin stopped; Hyprland session left running')
        return
    if action != 'swap-in':
        raise RuntimeError('Expected swap-in, swap-out or login')
    stable = stable_process()
    if stable is None:
        runtime = Path(os.environ['XDG_RUNTIME_DIR'])
        if fork_running(runtime):
            print('swap-in: anserin is already running')
            return
        if stable_running():
            raise RuntimeError('Stable is running without its PID file; no processes were stopped')
        session = current_session(runtime)
        pid = None
    else:
        pid, session = stable
    runtime = Path(session['XDG_RUNTIME_DIR'])
    run = runtime / 'anserin'
    run.mkdir(mode=0o700, parents=True, exist_ok=True)
    transition = start_transition(session, run)
    try:
        if pid is not None:
            stop_stable(pid)
        try:
            launch(ROOT / 'bin/anserind', session, True, run)
        except Exception:
            stop_fork(session)
            if pid is not None:
                launch(STABLE, session, False, run)
            raise
        startup_lock(session)
    finally:
        stop_transition(transition, session, run)
    print('swap-in: fork configuration loaded; Stable stopped' if pid is not None
          else 'swap-in: fork configuration loaded; Stable was already stopped')


if __name__ == '__main__':
    try:
        main(sys.argv[1])
    except Exception as error:
        print(f'Swap failed: {error}', file=sys.stderr)
        sys.exit(1)
