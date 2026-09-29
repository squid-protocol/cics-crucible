#!/usr/bin/env python3
"""Optional: compile every case program with GnuCOBOL (`cobc -fsyntax-only`) after
stubbing out the CICS translator's job. Standard library only.

Each `EXEC CICS ... END-EXEC` becomes `CONTINUE` (a trailing period is kept),
`DFHRESP(x)` becomes a number, the EIB stand-in (tools/stubs/DFHEIBLK.cpy) is copied
into WORKING-STORAGE, and the DFHAID / DFHBMSCA stand-ins resolve their COPYs. This
checks COBOL syntax only -- not the EXEC CICS commands, not behaviour.

    python3 tools/syntax_check.py            # uses cobc if on PATH, else Docker
    GNUCOBOL_IMAGE=gitgalaxy-gnucobol:3 python3 tools/syntax_check.py
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STUBS = ROOT / "tools" / "stubs"
RESP = {"NORMAL": 0, "ERROR": 1, "NOTFND": 13, "INVREQ": 16, "LENGERR": 22, "ITEMERR": 26, "PGMIDERR": 27,
        "TRANSIDERR": 28, "ENDDATA": 29, "MAPFAIL": 36, "QIDERR": 44, "ENVDEFERR": 56}


def stub(source: str) -> str:
    lines = source.splitlines()
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        code = line[7:72] if len(line) > 7 else ""
        m = re.search(r"\bEXEC\s+CICS\b", code) if not (len(line) > 6 and line[6] in "*/") else None
        if not m:
            out.append(line)
            i += 1
            continue
        prefix, body, j = code[: m.start()], code[m.end():], i
        while not re.search(r"\bEND-EXEC\b", body):
            j += 1
            nxt = lines[j]
            if len(nxt) > 6 and nxt[6] in "*/":
                continue
            body += " " + (nxt[7:72] if len(nxt) > 7 else "")
        suffix = body[re.search(r"\bEND-EXEC\b", body).end():]
        if prefix.strip():
            out.append(line[:7] + prefix.rstrip())
        out.append(" " * 11 + "CONTINUE" + suffix.rstrip())
        i = j + 1
    text = "\n".join(out) + "\n"
    text = re.sub(r"\bDFHRESP\s*\(\s*([A-Z0-9]+)\s*\)", lambda m: str(RESP[m.group(1).upper()]), text)
    text = re.sub(r"^(.{7}\s*WORKING-STORAGE\s+SECTION\.[^\n]*\n)", r"\1       COPY DFHEIBLK.\n", text,
                  count=1, flags=re.M)
    return text


def main(argv: list[str]) -> int:
    cases = [Path(a).resolve() for a in argv] or sorted(p.parent for p in (ROOT / "cases").glob("*/*/case.json"))
    image = os.environ.get("GNUCOBOL_IMAGE", "gitgalaxy-gnucobol:3")
    use_docker = shutil.which("cobc") is None
    if use_docker and shutil.which("docker") is None:
        print("neither cobc nor docker is available; skipping the syntax check")
        return 0
    failed = 0
    for case in cases:
        with tempfile.TemporaryDirectory(prefix="cicscru-") as tmp:
            work = Path(tmp)
            for p in STUBS.glob("*.cpy"):
                shutil.copy(p, work / p.name)
            if (case / "copy").is_dir():
                for p in (case / "copy").glob("*.cpy"):
                    shutil.copy(p, work / p.name)
            progs = sorted((case / "src").glob("*.cbl"))
            for p in progs:
                (work / p.name).write_text(stub(p.read_text(encoding="utf-8")), encoding="utf-8")
            for p in progs:
                cmd = ["cobc", "-fsyntax-only", "-std=ibm", "-I", ".", p.name]
                if use_docker:
                    cmd = ["docker", "run", "--rm", "-v", f"{work}:/work", "-w", "/work", image] + cmd
                r = subprocess.run(cmd, cwd=work, capture_output=True, text=True, check=False)
                rel = p.relative_to(ROOT)
                if r.returncode != 0:
                    failed += 1
                    print(f"{rel}: FAILED\n{r.stdout}{r.stderr}")
                else:
                    print(f"{rel}: ok" + (f"\n{r.stderr}" if r.stderr.strip() else ""))
    print("syntax check: " + ("all programs compile" if not failed else f"{failed} program(s) failed"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
