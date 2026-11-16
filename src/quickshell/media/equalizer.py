#!/usr/bin/env python3
"""Serialize EQ drafts and apply saved settings to Anserin's audio processor."""
import fcntl
import json
import math
import os
from pathlib import Path
import socket
import sys

PRESETS = {
    'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'Bass': [5, 7, 5, 2, 1, 0, 0, 0, 1, 2],
    'Treble': [-2, -1, 0, 1, 2, 3, 4, 5, 6, 6],
    'Vocal': [-2, -1, 1, 3, 5, 5, 4, 2, 1, 0],
    'Pop': [2, 4, 2, 0, 1, 2, 4, 2, 1, 2],
    'Rock': [5, 4, 2, -1, -2, -1, 2, 4, 5, 6],
    'Jazz': [3, 3, 1, 1, 1, 1, 2, 1, 2, 3],
    'Classic': [0, 1, 2, 2, 2, 2, 1, 2, 3, 4],
}


def manual(data):
    result = {'preset': data.get('preset', 'Flat')}
    for index in range(1, 11):
        value = float(data.get(f'b{index}', 0))
        if not math.isfinite(value) or not -24 <= value <= 24:
            raise ValueError('EQ gain must be finite and between -24 and 24 dB')
        result[f'b{index}'] = value
    return result


def send(data, dynamic):
    gains = ' '.join(str(data[f'b{i}']) for i in range(1, 11))
    command = f'set {gains} 0 0 0 off 0 {int(dynamic)}\n'
    path = Path(os.environ['QS_RUN_DIR']) / 'audio.sock'
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(3)
        client.connect(str(path))
        client.sendall(command.encode())
        reply = b''
        while b'\n' not in reply:
            part = client.recv(512)
            if not part:
                break
            reply += part
        if not reply.startswith(b'ok'):
            raise RuntimeError('Audio processor rejected EQ settings: ' + reply.decode(errors='replace').strip())


def write(path, data):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data) + '\n')
    os.replace(temporary, path)


def run(command, args):
    runtime = Path(os.environ['QS_RUN_DIR']) / 'music'
    state = Path(os.environ['QS_STATE_DIR']) / 'music'
    runtime.mkdir(parents=True, exist_ok=True)
    state.mkdir(parents=True, exist_ok=True)
    live, saved = runtime / 'eq_state.json', state / 'eq_state.json'
    with (runtime / 'equalizer.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        path = live if live.exists() else saved
        data = json.loads(path.read_text()) if path.exists() else dict(manual({}), pending=False, dyneq=False)
        manual(data)
        applied = manual(data.get('applied', data))
        dynamic = data.get('dyneq', False) is True
        if command == 'get':
            if not live.exists():
                write(live, data)
            return data
        if command == 'init':
            if args not in (['true'], ['false']):
                raise ValueError('init expects true or false')
            dynamic = args[0] == 'true'
            send(applied, dynamic)
            data['dyneq'] = dynamic
        elif command in ('set_band', 'preset', 'apply'):
            if dynamic:
                raise ValueError('Manual EQ is paused while Dynamic EQ is enabled')
            if command == 'set_band':
                if len(args) != 2 or not args[0].isdigit() or not 1 <= int(args[0]) <= 10:
                    raise ValueError('set_band expects a band from 1 to 10 and a gain')
                data[f'b{int(args[0])}'] = args[1]
                manual(data)
                data.update(preset='Custom', pending=True)
            elif command == 'preset':
                if len(args) != 1 or args[0] not in PRESETS:
                    raise ValueError('Unknown EQ preset')
                data.update({f'b{i+1}': v for i, v in enumerate(PRESETS[args[0]])})
                data['preset'] = args[0]
            if command != 'set_band':
                applied = manual(data)
                send(applied, False)
                data['pending'] = False
        else:
            raise ValueError('Expected get, init, set_band, preset or apply')
        data['applied'] = applied
        write(saved, data)
        write(live, data)
        return data


if __name__ == '__main__':
    try:
        print(json.dumps(run(sys.argv[1], sys.argv[2:])))
    except (OSError, ValueError, RuntimeError, IndexError, KeyError, TypeError) as error:
        print('Equalizer: ' + str(error), file=sys.stderr)
        sys.exit(1)
