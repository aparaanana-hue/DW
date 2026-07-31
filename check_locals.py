#!/usr/bin/env python3
"""Report how close each Luau scope is to the 200-local limit.

Luau allows at most 200 active locals per scope. Exceeding it is a COMPILE
error, so the whole chunk fails and loadstring() returns nil - in game that
looks like a bare "Line 1" stack trace with no message.

luau-analyze does NOT catch this: it parses and typechecks but never allocates
registers. `luau file.lua` does, but stops at the first offending scope. This
reports every scope with its headroom so it can be caught before shipping.

Usage:
    python3 check_locals.py IAB.lua [--warn=150]
Exit code 1 if any scope is at or over the limit.
"""
import re
import sys

# strip string literals and comments so keywords inside them are not counted
STRINGS = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|\[\[.*?\]\]', re.S)
LINE_COMMENT = re.compile(r'--.*$')

W = lambda k: re.compile(r'\b' + k + r'\b')
RE_FUNCTION = W('function')
RE_IF = re.compile(r'(?<!else)\bif\b')     # elseif continues a scope, not a new one
RE_FOR = W('for')
RE_WHILE = W('while')
RE_REPEAT = W('repeat')
RE_DO = W('do')
RE_END = W('end')
RE_UNTIL = W('until')
RE_LOCAL = re.compile(r'^\s*local\b')


def clean(line):
    line = STRINGS.sub('""', line)
    return LINE_COMMENT.sub('', line)


def scan(path, warn, limit):
    lines = open(path, encoding='utf-8').read().split('\n')
    # each frame: [label, start_line, local_count]
    stack = [['<main chunk>', 1, 0]]
    finished = []

    for n, raw in enumerate(lines, 1):
        line = clean(raw)
        if not line.strip():
            continue

        if RE_LOCAL.match(line):
            stack[-1][2] += 1

        n_for = len(RE_FOR.findall(line))
        n_while = len(RE_WHILE.findall(line))
        # a `do` belonging to for/while is part of that opener, not its own
        n_do = max(len(RE_DO.findall(line)) - n_for - n_while, 0)

        opens = (len(RE_FUNCTION.findall(line)) + len(RE_IF.findall(line))
                 + n_for + n_while + len(RE_REPEAT.findall(line)) + n_do)
        closes = len(RE_END.findall(line)) + len(RE_UNTIL.findall(line))

        for _ in range(opens):
            label = 'do-block' if line.strip().startswith('do') else 'scope'
            stack.append([f'{label} @{n}', n, 0])
        for _ in range(closes):
            if len(stack) > 1:
                lbl, start, cnt = stack.pop()
                finished.append((cnt, lbl, start, n))

    while stack:
        lbl, start, cnt = stack.pop()
        finished.append((cnt, lbl, start, len(lines)))

    return sorted([f for f in finished if f[0] >= warn], reverse=True)


def main():
    files = [a for a in sys.argv[1:] if not a.startswith('--')]
    if not files:
        print(__doc__)
        return 2
    warn, limit = 150, 200
    for a in sys.argv[1:]:
        if a.startswith('--warn='):
            warn = int(a.split('=')[1])

    bad = False
    for path in files:
        worst = scan(path, warn, limit)
        print(f'== {path} ==')
        if not worst:
            print(f'   every scope under {warn} locals - plenty of headroom')
        for cnt, lbl, start, end in worst[:12]:
            if cnt >= limit:
                bad = True
                flag = 'OVER LIMIT'
            else:
                flag = f'{limit - cnt} left'
            print(f'   {cnt:4d} locals  {flag:12}  {lbl} (lines {start}-{end})')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
