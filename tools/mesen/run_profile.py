#!/usr/bin/env python3
"""Run tools/mesen/profile.lua headless (Mesen 2 --testrunner), one emulator at a time.

usage: python tools/mesen/run_profile.py --out DIR [--mesen mesen] [--frames N] [--runs SPEC ...]

The Mesen folder is copied into <out>/mesen with Lua IO on and zeroed RAM (the installed copy is not touched).
Each --runs SPEC is "name:seed:players:lives:pause[:clear]", e.g. "p1:1:1:6000:900:1500" (see profile.lua for the
fields; players 0 = title and demo only). Default: one 1-player and one 2-player run.
Results: <out>/<name>.{acc,vals,exec,args,trace} and screenshots; summarise them with tools/xref.py --logs <out>.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ROM = os.path.join(ROOT, 'galaxian.nes')


def setup(mesen_src, work):
    os.makedirs(work, exist_ok=True)
    for f in ['Mesen.exe', 'MesenCore.dll', 'libHarfBuzzSharp.dll', 'libSkiaSharp.dll', 'settings.json']:
        dst = os.path.join(work, f)
        if not os.path.exists(dst) or f == 'settings.json':
            shutil.copy2(os.path.join(mesen_src, f), dst)
    p = os.path.join(work, 'settings.json')
    s = open(p, encoding='utf-8').read()
    s = s.replace('"AllowIoOsAccess": false', '"AllowIoOsAccess": true')
    s = re.sub(r'"ScriptTimeout": \d+', '"ScriptTimeout": 100', s)
    s = s.replace('"RamPowerOnState": "Random"', '"RamPowerOnState": "AllZeros"')
    open(p, 'w', encoding='utf-8').write(s)


def lua_str(p):
    return '[[' + os.path.abspath(p) + ']]'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--mesen', default=os.path.join(ROOT, 'mesen'))
    ap.add_argument('--out', required=True)
    ap.add_argument('--frames', type=int, default=12000)
    ap.add_argument('--runs', nargs='*', default=['p1:1:1:6000:900', 'p2:2:2:6000:0'])
    ap.add_argument('--no-shots', action='store_true')
    ap.add_argument('--labels', default=os.path.join(os.path.dirname(HERE), 'labels'))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    work = os.path.join(a.out, 'mesen')
    setup(a.mesen, work)
    rc = 0
    sys.path.insert(0, os.path.dirname(HERE))
    import xref
    entries = ', '.join('0x%04X' % (0xE000 + i) for i in sorted(xref.routine_entries(xref.load_disasm(a.labels))))
    for spec in a.runs:                                  # sequential: only one emulator instance at a time
        name, seed, players, lives, pause, clear = (spec.split(':') + ['0'])[:6]
        prefix = os.path.join(a.out, name)
        cfg = ('CFG = { out = %s, frames = %d, seed = %s, players = %s, lives = %s, pause = %s, clear = %s, shots = %s,'
               ' entries = { %s } }\n') % (lua_str(prefix), a.frames, seed, players, lives, pause, clear,
                                          'false' if a.no_shots else 'true', entries)
        script = prefix + '.lua'
        open(script, 'w').write(cfg + open(os.path.join(HERE, 'profile.lua')).read())
        r = subprocess.run([os.path.join(work, 'Mesen.exe'), '--testrunner', os.path.abspath(ROM), script,
                            '--timeout=3000'], capture_output=True, text=True, errors='replace')
        ok = os.path.exists(prefix + '.exec')
        print('%s: exit %d%s' % (name, r.returncode, '' if ok else ' (no output)'))
        if not ok:
            print((r.stdout + r.stderr)[-2000:])
            rc = 1
    return rc


if __name__ == '__main__':
    sys.exit(main())
