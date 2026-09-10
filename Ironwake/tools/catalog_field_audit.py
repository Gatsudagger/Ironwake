"""Catalog field audit (09-09): the Hippocamp crash class - a catalog entry that
lacks a field its siblings have, read raw by a loop somewhere. For every
`function *catalog*` (and *_table / *_defs) in scripts/, collect the keys of each
`{ ... }` entry and report keys that only SOME entries carry. Heuristic: one
entry per line (the house style). Review the report by hand - a missing key is
only a crash if some reader touches it unguarded.
"""
import os, re, glob
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
key_re = re.compile(r'(?:^|[{,]\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:')
for path in sorted(glob.glob(os.path.join(ROOT, "scripts", "*", "*.gml"))):
    src = open(path, encoding="utf-8", errors="replace").read()
    for m in re.finditer(r"^function\s+(\w*(?:catalog|_table|_defs|_list)\w*)\s*\(", src, re.M):
        name = m.group(1)
        start = m.end()
        # crude function extent: up to the next top-level "function " or EOF
        nxt = re.search(r"^function\s", src[start:], re.M)
        body = src[start:start + nxt.start()] if nxt else src[start:]
        entries = []
        for line in body.splitlines():
            t = line.strip()
            if t.startswith("{") and t.count("{") >= 1 and ("id:" in t or "name:" in t):
                keys = set(key_re.findall(t.split("//")[0]))
                keys.discard("")
                if keys:
                    entries.append((keys, t[:70]))
        if len(entries) < 3:
            continue
        allk = set().union(*(k for k, _ in entries))
        common = set.intersection(*(k for k, _ in entries))
        partial = sorted(allk - common)
        if not partial:
            continue
        # only report keys missing from a MINORITY of entries (the outlier pattern)
        report = []
        for k in partial:
            missing = [t for keys, t in entries if k not in keys]
            if 0 < len(missing) <= max(3, len(entries) // 4):
                report.append((k, missing))
        if report:
            print(f"\n== {os.path.relpath(path, ROOT)} :: {name}  ({len(entries)} entries)")
            for k, missing in report:
                print(f"   key '{k}' missing in {len(missing)}:")
                for t in missing[:4]:
                    print("      ", t)
