#!/usr/bin/env python3
"""Validate every cics-crucible case (SPEC.md section 8). Standard library only.

    python3 tools/validate.py            # every case under cases/
    python3 tools/validate.py cases/ghost-tasks/gt-start-retrieve

Exit status 0 when every case is valid; otherwise each problem is printed as
`<case dir>: <problem>` and the status is 1.
"""

from __future__ import annotations

import json
import re
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
SCHEMAS = ROOT / "schema"
IBM_COPYBOOKS = {"DFHAID", "DFHBMSCA"}
NOTES_SECTIONS = ["The trap", "Why a naive translation breaks", "Expected behaviour",
                  "What a correct port must do", "Avoided ambiguities", "Citations"]
EXTATTR_SUFFIX = [("COLOR", "C"), ("PS", "P"), ("HILIGHT", "H"), ("VALIDN", "V")]


# ---- a JSON Schema subset (the keywords schema/*.json use) ----------------------------
class SchemaChecker:
    def __init__(self, schema: dict[str, Any]):
        self.root = schema

    def resolve(self, s: dict[str, Any]) -> dict[str, Any]:
        while "$ref" in s:
            ref = s["$ref"]
            assert ref.startswith("#/"), ref
            node: Any = self.root
            for part in ref[2:].split("/"):
                node = node[part]
            s = node
        return s

    def check(self, v: Any, s: dict[str, Any] | None = None, path: str = "$") -> list[str]:
        s = self.resolve(self.root if s is None else s)
        errs: list[str] = []
        t = s.get("type")
        if t is not None and not self._is_type(v, t):
            return [f"{path}: expected {t}, got {type(v).__name__}"]
        if "const" in s and v != s["const"]:
            return [f"{path}: expected {s['const']!r}, got {v!r}"]
        if "enum" in s and v not in s["enum"]:
            return [f"{path}: {v!r} not one of {s['enum']}"]
        if isinstance(v, str):
            if "pattern" in s and not re.search(s["pattern"], v):
                errs.append(f"{path}: {v!r} does not match {s['pattern']}")
            if "minLength" in s and len(v) < s["minLength"]:
                errs.append(f"{path}: shorter than {s['minLength']}")
        if isinstance(v, int) and not isinstance(v, bool):
            if "minimum" in s and v < s["minimum"]:
                errs.append(f"{path}: {v} < {s['minimum']}")
        if isinstance(v, list):
            if "minItems" in s and len(v) < s["minItems"]:
                errs.append(f"{path}: fewer than {s['minItems']} items")
            if "items" in s:
                for i, item in enumerate(v):
                    errs += self.check(item, s["items"], f"{path}[{i}]")
        if isinstance(v, dict):
            for r in s.get("required", []):
                if r not in v:
                    errs.append(f"{path}: missing {r!r}")
            props = s.get("properties", {})
            for k, item in v.items():
                if k in props:
                    errs += self.check(item, props[k], f"{path}.{k}")
                elif s.get("additionalProperties") is False:
                    errs.append(f"{path}: unexpected key {k!r}")
                elif isinstance(s.get("additionalProperties"), dict):
                    errs += self.check(item, s["additionalProperties"], f"{path}.{k}")
        if "oneOf" in s:
            errs += self._one_of(v, s["oneOf"], path)
        return errs

    def _one_of(self, v: Any, branches: list[dict[str, Any]], path: str) -> list[str]:
        resolved = [self.resolve(b) for b in branches]
        # a discriminated union (every branch fixes "event"): pick the branch by it
        tags = [b.get("properties", {}).get("event", {}).get("const") for b in resolved]
        if all(tags) and isinstance(v, dict):
            if v.get("event") not in tags:
                return [f"{path}: unknown event {v.get('event')!r}"]
            return self.check(v, resolved[tags.index(v["event"])], path)
        results = [self.check(v, b, path) for b in resolved]
        ok = [r for r in results if not r]
        if len(ok) == 1:
            return []
        if not ok:
            best = min(results, key=len)
            return [f"{path}: matches no alternative ({best[0]})"]
        return [f"{path}: matches more than one alternative"]

    @staticmethod
    def _is_type(v: Any, t: str) -> bool:
        return {
            "object": isinstance(v, dict), "array": isinstance(v, list), "string": isinstance(v, str),
            "integer": isinstance(v, int) and not isinstance(v, bool), "boolean": isinstance(v, bool),
            "null": v is None, "number": isinstance(v, (int, float)) and not isinstance(v, bool),
        }[t]


# ---- COBOL source ---------------------------------------------------------------------
def cobol_code(path: Path) -> list[str]:
    """Columns 8-72 of each non-comment line (fixed format)."""
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if len(line) > 72 and line[72:].strip():
            raise ValueError(f"{path.name}: text beyond column 72: {line!r}")
        if len(line) > 6 and line[6] in "*/":
            continue
        out.append(line[7:72] if len(line) > 7 else "")
    return out


def cics_options(text: str) -> list[tuple[str, str | None]]:
    out, i, n = [], 0, len(text)
    while i < n:
        if text[i].isspace():
            i += 1
            continue
        m = re.match(r"[A-Z0-9-]+", text[i:], re.I)
        if not m:
            raise ValueError(f"cannot read EXEC CICS options at {text[i:i + 30]!r}")
        name, i = m.group(0).upper(), i + m.end()
        while i < n and text[i].isspace():
            i += 1
        value = None
        if i < n and text[i] == "(":
            depth, j, quote = 0, i, None
            while j < n:
                c = text[j]
                if quote:
                    quote = None if c == quote else quote
                elif c in "'\"":
                    quote = c
                elif c == "(":
                    depth += 1
                elif c == ")":
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            value, i = " ".join(text[i + 1:j].split()), j + 1
        out.append((name, value))
    return out


def exec_cics(code: list[str]) -> list[list[tuple[str, str | None]]]:
    text = "\n".join(code)
    return [cics_options(m.group(1)) for m in re.finditer(r"\bEXEC\s+CICS\b(.*?)\bEND-EXEC\b", text, re.S | re.I)]


def literal(v: str | None) -> str | None:
    m = re.fullmatch(r"'([^']*)'|\"([^\"]*)\"", (v or "").strip())
    return (m.group(1) if m.group(1) is not None else m.group(2)) if m else None


# ---- data descriptions and layouts ----------------------------------------------------
def data_entries(code: list[str]) -> list[dict[str, Any]]:
    """Every data description entry (level, name, clauses) in source order."""
    text = " ".join(code)
    # split into sentences on periods followed by space/end, outside quotes
    sentences, cur, quote = [], [], None
    for i, c in enumerate(text):
        if quote:
            cur.append(c)
            if c == quote:
                quote = None
            continue
        if c in "'\"":
            quote = c
            cur.append(c)
            continue
        if c == "." and (i + 1 == len(text) or text[i + 1] == " "):
            sentences.append("".join(cur).strip())
            cur = []
            continue
        cur.append(c)
    out = []
    for s in sentences:
        m = re.match(r"^(\d{1,2})\s+([A-Z0-9][A-Z0-9-]*)?\s*(.*)$", s, re.I | re.S)
        if not m:
            continue
        level = int(m.group(1))
        name = (m.group(2) or "FILLER").upper()
        rest = m.group(3)
        if name in ("PIC", "PICTURE", "REDEFINES", "VALUE", "USAGE", "COMP", "COMP-3", "OCCURS"):
            rest, name = f"{name} {rest}", "FILLER"
        pic = re.search(r"\bPIC(?:TURE)?\s+(?:IS\s+)?(\S+)", rest, re.I)
        red = re.search(r"\bREDEFINES\s+([A-Z0-9-]+)", rest, re.I)
        occ = re.search(r"\bOCCURS\s+(\d+)", rest, re.I)
        usage = "DISPLAY"
        for u, norm in (("COMP-3", "COMP-3"), ("COMPUTATIONAL-3", "COMP-3"), ("PACKED-DECIMAL", "COMP-3"),
                        ("COMP-5", "COMP"), ("COMP-4", "COMP"), ("BINARY", "COMP"), ("COMPUTATIONAL", "COMP"),
                        ("COMP", "COMP")):
            if re.search(rf"(?<![A-Z0-9-]){re.escape(u)}(?![A-Z0-9-])", rest, re.I):
                usage = norm
                break
        out.append({"level": level, "name": name, "pic": pic.group(1).upper() if pic else None,
                    "redefines": red.group(1).upper() if red else None,
                    "occurs": int(occ.group(1)) if occ else None, "usage": usage})
    return out


def pic_info(pic: str) -> tuple[bool, bool, int, int, int]:
    """(numeric, signed, integer digits, decimal digits, display size) of a PICTURE."""
    exp = re.sub(r"(.)\((\d+)\)", lambda m: m.group(1) * int(m.group(2)), pic)
    numeric = bool(re.fullmatch(r"S?9*V?9*", exp)) and "9" in exp
    signed = exp.startswith("S")
    if numeric:
        ip, _, dp = exp.lstrip("S").partition("V")
        return True, signed, ip.count("9"), dp.count("9"), len(ip) + len(dp)
    return False, False, 0, 0, len(exp.replace("S", "").replace("V", ""))


def elementary_size(e: dict[str, Any]) -> int:
    numeric, _signed, ip, dp, disp = pic_info(e["pic"])
    if e["usage"] == "COMP-3":
        return (ip + dp) // 2 + 1
    if e["usage"] == "COMP":
        d = ip + dp
        return 2 if d <= 4 else 4 if d <= 9 else 8
    return disp


def layout(code: list[str], record: str) -> dict[str, dict[str, Any]]:
    """{field name: {offset, size, pic, usage, elementary, optional}} for 01 `record`."""
    entries = data_entries(code)
    start = next((i for i, e in enumerate(entries) if e["level"] == 1 and e["name"] == record), None)
    if start is None:
        raise KeyError(record)
    end = next((i for i in range(start + 1, len(entries)) if entries[i]["level"] in (1, 77)), len(entries))
    items = [e for e in entries[start:end] if e["level"] not in (66, 88)]
    fields: dict[str, dict[str, Any]] = {}

    def walk(i: int, offset: int, optional: bool) -> tuple[int, int]:
        """Lay out items[i] and its subordinates at `offset`; (next index, size)."""
        e = items[i]
        j, size = i + 1, 0
        if e["pic"]:
            size = elementary_size(e)
        else:
            at = offset
            while j < len(items) and items[j]["level"] > e["level"]:
                child = items[j]
                child_off = at
                if child["redefines"]:
                    child_off = fields[child["redefines"]]["offset"]
                j, csize = walk(j, child_off, optional or bool(child["redefines"]) or bool(e["occurs"]))
                if not child["redefines"]:
                    at += csize
            size = at - offset
        total = size * (e["occurs"] or 1)
        if e["name"] != "FILLER":
            fields[e["name"]] = {"offset": offset, "size": size, "pic": e["pic"], "usage": e["usage"],
                                 "elementary": bool(e["pic"]), "optional": optional or bool(e["occurs"])}
        return j, total

    _, size = walk(0, 0, False)
    fields[record]["size"] = size
    return fields


# ---- CSD and BMS ----------------------------------------------------------------------
def csd_resources(path: Path) -> dict[str, dict[str, dict[str, str]]]:
    """{resource type: {name: {attribute: value}}} from a DFHCSDUP deck."""
    out: dict[str, dict[str, dict[str, str]]] = {}
    records, cur = [], None
    for raw in path.read_text(encoding="utf-8").splitlines():
        s = raw.strip()
        if not s or s.startswith("*"):
            if cur:
                records.append(cur)
            cur = None
            continue
        if re.match(r"(DEFINE|ADD|LIST|DELETE)\b", s, re.I):
            if cur:
                records.append(cur)
            cur = s if s.upper().startswith("DEFINE") else None
            continue
        if cur is not None:
            cur += " " + s
    if cur:
        records.append(cur)
    for r in records:
        m = re.match(r"DEFINE\s+([A-Z]+)\s*\(\s*([^)\s]+)\s*\)(.*)$", r, re.I | re.S)
        if not m:
            raise ValueError(f"{path.name}: cannot read {r[:40]!r}")
        attrs = {k.upper(): v.strip() for k, v in re.findall(r"([A-Z]+)\s*\(([^)]*)\)", m.group(3), re.I)}
        out.setdefault(m.group(1).upper(), {})[m.group(2).upper()] = attrs
    return out


def bms_statements(path: Path) -> list[tuple[str, str, str]]:
    """(label, macro, operand string) per statement, continuation in column 72 joined."""
    stmts, lines = [], path.read_text(encoding="utf-8").splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        if len(line) > 80:
            raise ValueError(f"{path.name} line {i + 1}: longer than 80 columns")
        if not line.strip() or line.startswith("*"):
            i += 1
            continue
        cont = len(line) > 71 and line[71] not in " "
        # a continued line ends at column 71; blanks before the mark are padding (the
        # crucible never splits a quoted literal across lines)
        body = line[:71].rstrip() if cont else line[:71]
        while cont:
            i += 1
            nxt = lines[i]
            if nxt[:15].strip():
                raise ValueError(f"{path.name} line {i + 1}: a continuation line must start in column 16")
            cont = len(nxt) > 71 and nxt[71] not in " "
            body += nxt[15:71].rstrip() if cont else nxt[15:71]
        m = re.match(r"^(\S*)\s+(\S+)\s*(.*)$", body)
        if m:
            label, macro, rest = m.group(1), m.group(2).upper(), m.group(3)
            # operands end at the first blank outside quotes
            ops, quote = [], False
            for c in rest:
                if c == "'":
                    quote = not quote
                if c == " " and not quote:
                    break
                ops.append(c)
            stmts.append((label.upper(), macro, "".join(ops)))
        i += 1
    return stmts


def bms_operands(ops: str) -> dict[str, str]:
    out, i = {}, 0
    while i < len(ops):
        m = re.match(r"([A-Z]+)=", ops[i:], re.I)
        if not m:
            break
        key, i = m.group(1).upper(), i + m.end()
        depth, quote, j = 0, False, i
        while j < len(ops):
            c = ops[j]
            if c == "'":
                quote = not quote
            elif not quote and c == "(":
                depth += 1
            elif not quote and c == ")":
                depth -= 1
            elif not quote and c == "," and depth == 0:
                break
            j += 1
        out[key] = ops[i:j]
        i = j + 1
    return out


def bms_maps(path: Path) -> dict[str, dict[str, Any]]:
    """{map: {mapset, dsatts, fields: [{name, length, attrb}]}} (fields in order, named only)."""
    maps: dict[str, dict[str, Any]] = {}
    mapset, ms_dsatts, cur = None, [], None
    for label, macro, ops in bms_statements(path):
        o = bms_operands(ops)
        if macro == "DFHMSD":
            if o.get("TYPE", "").upper() != "FINAL":
                mapset = label
                ms_dsatts = [a.strip().upper() for a in o.get("DSATTS", "").strip("()").split(",") if a.strip()]
        elif macro == "DFHMDI":
            ds = [a.strip().upper() for a in o.get("DSATTS", "").strip("()").split(",") if a.strip()] or ms_dsatts
            cur = maps[label] = {"mapset": mapset, "dsatts": ds, "fields": []}
        elif macro == "DFHMDF" and cur is not None:
            attrb = [a.strip().upper() for a in o.get("ATTRB", "").strip("()").split(",") if a.strip()]
            if label:
                cur["fields"].append({"name": label, "length": int(o.get("LENGTH", "0")), "attrb": attrb,
                                      "has_attrb": "ATTRB" in o})
    return maps


GRAPHIC = bytes.fromhex(
    "40C1C2C3C4C5C6C7C8C94A4B4C4D4E4F" "50D1D2D3D4D5D6D7D8D95A5B5C5D5E5F"
    "6061E2E3E4E5E6E7E8E96A6B6C6D6E6F" "F0F1F2F3F4F5F6F7F8F97A7B7C7D7E7F")


def attrb_byte(attrb: list[str], given: bool) -> int:
    """The 3270 attribute byte a DFHMDF ATTRB produces (SPEC 6.3)."""
    if not given:
        attrb = ["ASKIP", "NORM"]
    v = 0
    if "ASKIP" in attrb:
        v |= 0x30
    elif "PROT" in attrb:
        v |= 0x20
    elif "NUM" in attrb:
        v |= 0x10
    if "BRT" in attrb:
        v |= 0x08
    elif "DRK" in attrb:
        v |= 0x0C
    elif "DET" in attrb:
        v |= 0x04
    if "FSET" in attrb:
        v |= 0x01
    return GRAPHIC[v]


def attr_meaning(b: int) -> dict[str, Any]:
    disp = {0x00: "normal", 0x04: "normal", 0x08: "bright", 0x0C: "dark"}[b & 0x0C]
    return {"protected": bool(b & 0x20), "numeric": bool(b & 0x10), "display": disp, "mdt": bool(b & 0x01)}


# ---- one case -------------------------------------------------------------------------
class Case:
    def __init__(self, d: Path):
        self.dir = d
        self.problems: list[str] = []

    def err(self, msg: str) -> None:
        self.problems.append(msg)

    def run(self) -> list[str]:
        try:
            self._run()
        except Exception as e:  # noqa: BLE001 -- report and carry on to the next case
            self.err(f"validator crashed: {type(e).__name__}: {e}")
        return self.problems

    def _run(self) -> None:
        d = self.dir
        case_schema = SchemaChecker(json.loads((SCHEMAS / "case.schema.json").read_text()))
        exp_schema = SchemaChecker(json.loads((SCHEMAS / "expected.schema.json").read_text()))
        cj = d / "case.json"
        if not cj.is_file():
            return self.err("no case.json")
        case = json.loads(cj.read_text(encoding="utf-8"))
        errs = case_schema.check(case)
        if errs:
            for e in errs:
                self.err(f"case.json {e}")
            return
        if case["id"] != d.name:
            self.err(f"case id {case['id']!r} is not the directory name")
        if case["trap"] != d.parent.name:
            self.err(f"trap {case['trap']!r} is not the parent directory")
        self.case = case
        self._sources()
        self._layouts()
        self._maps()
        self._programs()
        self._scenarios()
        ids = [s["id"] for s in case["scenarios"]]
        if len(set(ids)) != len(ids):
            self.err("duplicate scenario ids")
        exp_dir = d / "expected"
        files = {p.stem for p in exp_dir.glob("*.json")} if exp_dir.is_dir() else set()
        for missing in sorted(set(ids) - files):
            self.err(f"scenario {missing}: no expected/{missing}.json")
        for stray in sorted(files - set(ids)):
            self.err(f"expected/{stray}.json: no such scenario")
        for sc in case["scenarios"]:
            p = exp_dir / f"{sc['id']}.json"
            if p.is_file():
                log = json.loads(p.read_text(encoding="utf-8"))
                errs = exp_schema.check(log)
                if errs:
                    for e in errs:
                        self.err(f"expected/{p.name} {e}")
                    continue
                self._expected(sc, log, p.name)
        self._notes()

    # -- sources
    def _sources(self) -> None:
        c, d = self.case, self.dir
        for kind in ("cobol", "bms", "csd", "data"):
            for rel in c["sources"][kind]:
                if not (d / rel).exists():
                    self.err(f"missing source {rel}")
        self.copydirs = [d / p for p in c["sources"]["copy"]]
        self.csd: dict[str, dict[str, dict[str, str]]] = {}
        for rel in c["sources"]["csd"]:
            if (d / rel).is_file():
                for t, recs in csd_resources(d / rel).items():
                    self.csd.setdefault(t, {}).update(recs)
        self.programs = set(self.csd.get("PROGRAM", {}))
        self.transactions = {t: a.get("PROGRAM", "").upper() for t, a in self.csd.get("TRANSACTION", {}).items()}
        self.mapsets_csd = set(self.csd.get("MAPSET", {}))
        self.files_csd = set(self.csd.get("FILE", {}))
        for t, p in self.transactions.items():
            if p not in self.programs:
                self.err(f"CSD transaction {t} names program {p!r}, which has no DEFINE PROGRAM")
        self.bms: dict[str, dict[str, Any]] = {}
        for rel in c["sources"]["bms"]:
            if (d / rel).is_file():
                maps = bms_maps(d / rel)
                for m, info in maps.items():
                    if info["mapset"] != Path(rel).stem:
                        self.err(f"{rel}: mapset {info['mapset']} is not the file stem")
                    if info["mapset"] not in self.mapsets_csd:
                        self.err(f"mapset {info['mapset']} has no CSD DEFINE MAPSET")
                self.bms.update(maps)
        self.src: dict[str, list[str]] = {}
        for rel in c["sources"]["cobol"]:
            p = d / rel
            if not p.is_file():
                continue
            code = cobol_code(p)
            self.src[rel] = code
            m = re.search(r"PROGRAM-ID\.\s+([A-Z0-9#@$]+)", "\n".join(code), re.I)
            pid = m.group(1).upper() if m else None
            if pid != p.stem:
                self.err(f"{rel}: PROGRAM-ID {pid} is not the file stem")
            if pid not in self.programs:
                self.err(f"{rel}: program {pid} has no CSD DEFINE PROGRAM")
        missing = self.programs - {Path(r).stem for r in c["sources"]["cobol"]}
        for p in sorted(missing):
            self.err(f"CSD program {p} has no source in src/")

    def code_of(self, rel: str) -> list[str]:
        """A source's code with its COPY statements expanded from the case's copy directories
        (IBM-supplied members are left out: they never hold a layout a case uses)."""
        code = self.src.get(rel) or cobol_code(self.dir / rel)
        out: list[str] = []
        for line in code:
            m = re.fullmatch(r"\s*COPY\s+([A-Z0-9#@$-]+)\s*\.\s*", line, re.I)
            if not m:
                out.append(line)
                continue
            hit = next((cd / f"{m.group(1).upper()}.cpy" for cd in self.copydirs
                        if (cd / f"{m.group(1).upper()}.cpy").is_file()), None)
            if hit is not None:
                out += cobol_code(hit)
        return out

    def _layouts(self) -> None:
        self.layouts: dict[str, dict[str, dict[str, Any]]] = {}
        for name, spec in self.case["layouts"].items():
            p = self.dir / spec["source"]
            if not p.is_file():
                self.err(f"layout {name}: no {spec['source']}")
                continue
            try:
                self.layouts[name] = layout(self.code_of(spec["source"]), spec["record"])
            except KeyError:
                self.err(f"layout {name}: no 01 {spec['record']} in {spec['source']}")

    def _maps(self) -> None:
        for m, spec in self.case["maps"].items():
            info = self.bms.get(m)
            if info is None:
                self.err(f"map {m}: not in the BMS sources")
                continue
            if info["mapset"] != spec["mapset"]:
                self.err(f"map {m}: mapset is {info['mapset']}, case.json says {spec['mapset']}")
            p = self.dir / spec["copybook"]
            if not p.is_file():
                self.err(f"map {m}: no {spec['copybook']}")
                continue
            code = cobol_code(p)
            try:
                li, lo = layout(code, f"{m}I"), layout(code, f"{m}O")
            except KeyError as e:
                self.err(f"{spec['copybook']}: no 01 {e.args[0]}")
                continue
            suffixes = [s for a, s in EXTATTR_SUFFIX if a in info["dsatts"]]
            unknown = [a for a in info["dsatts"] if a not in dict(EXTATTR_SUFFIX)]
            if unknown:
                self.err(f"map {m}: DSATTS {unknown} not supported by the validator")
            off = 12
            for f in info["fields"]:
                n, ln = f["name"], f["length"]
                want = {f"{n}L": (off, 2), f"{n}F": (off + 2, 1), f"{n}A": (off + 2, 1),
                        f"{n}I": (off + 3 + len(suffixes), ln)}
                wanto = {f"{n}O": (off + 3 + len(suffixes), ln)}
                wanto.update({f"{n}{s}": (off + 3 + k, 1) for k, s in enumerate(suffixes)})
                for side, lay, w in (("I", li, want), ("O", lo, wanto)):
                    for name, (o, sz) in w.items():
                        got = lay.get(name)
                        if got is None:
                            self.err(f"{spec['copybook']}: {m}{side} has no {name}")
                        elif (got["offset"], got["size"]) != (o, sz):
                            self.err(f"{spec['copybook']}: {name} at {got['offset']}+{got['size']}, BMS says {o}+{sz}")
                off += 3 + len(suffixes) + ln
            if li[f"{m}I"]["size"] != off:
                self.err(f"{spec['copybook']}: {m}I is {li[f'{m}I']['size']} bytes, BMS gives {off}")

    def _programs(self) -> None:
        undefined = set(self.case.get("undefined_programs", []))
        for rel, code in self.src.items():
            for opts in exec_cics(code):
                verb = opts[0][0]
                o = dict(opts)
                if verb in ("LINK", "XCTL") and literal(o.get("PROGRAM")):
                    p = literal(o["PROGRAM"]).upper()
                    if p not in self.programs and p not in undefined:
                        self.err(f"{rel}: {verb} PROGRAM('{p}') is not defined (CSD or undefined_programs)")
                if verb in ("RETURN", "START") and literal(o.get("TRANSID")):
                    t = literal(o["TRANSID"]).upper()
                    if t not in self.transactions:
                        self.err(f"{rel}: {verb} TRANSID('{t}') has no CSD DEFINE TRANSACTION")
                if verb in ("SEND", "RECEIVE") and "MAP" in o and literal(o["MAP"]):
                    m = literal(o["MAP"]).upper()
                    ms = (literal(o.get("MAPSET")) or m).upper()
                    if m not in self.bms:
                        self.err(f"{rel}: MAP('{m}') is not in the BMS sources")
                    elif self.bms[m]["mapset"] != ms:
                        self.err(f"{rel}: MAP('{m}') is in mapset {self.bms[m]['mapset']}, not {ms}")
                    if m not in self.case["maps"]:
                        self.err(f"{rel}: MAP('{m}') is not listed in case.json maps")
                if verb in ("READ", "WRITE", "REWRITE", "DELETE", "STARTBR") and literal(o.get("FILE")):
                    f = literal(o["FILE"]).upper()
                    if f not in self.files_csd:
                        self.err(f"{rel}: FILE('{f}') has no CSD DEFINE FILE")
            for m in re.finditer(r"\bCOPY\s+([A-Z0-9#@$-]+)", "\n".join(code), re.I):
                name = m.group(1).upper()
                if name in IBM_COPYBOOKS:
                    continue
                if not any((cd / f"{name}.cpy").is_file() for cd in self.copydirs):
                    self.err(f"{rel}: COPY {name} does not resolve in {self.case['sources']['copy']}")

    def _scenarios(self) -> None:
        for sc in self.case["scenarios"]:
            last = -1
            for i, st in enumerate(sc["steps"]):
                if st["at"] <= last:
                    self.err(f"scenario {sc['id']} step {i}: 'at' must increase")
                last = st["at"]
                if "text" in st and ("map" in st or "fields" in st):
                    self.err(f"scenario {sc['id']} step {i}: text and map input together")
                if "fields" in st and "map" not in st:
                    self.err(f"scenario {sc['id']} step {i}: fields without map")
                if st["aid"] in ("CLEAR", "PA1", "PA2", "PA3") and ("text" in st or st.get("fields")):
                    self.err(f"scenario {sc['id']} step {i}: {st['aid']} transmits no data")
                if "map" in st:
                    info = self.bms.get(st["map"])
                    if info is None:
                        self.err(f"scenario {sc['id']} step {i}: no map {st['map']}")
                        continue
                    names = {f["name"]: f for f in info["fields"]}
                    for fname, v in st.get("fields", {}).items():
                        if fname not in names:
                            self.err(f"scenario {sc['id']} step {i}: {st['map']} has no field {fname}")
                        elif isinstance(v, str) and len(v.encode("cp037")) > names[fname]["length"]:
                            self.err(f"scenario {sc['id']} step {i}: {fname} longer than the field")
                    if "cursor" in st and st["cursor"] not in names:
                        self.err(f"scenario {sc['id']} step {i}: cursor field {st['cursor']} not in map")

    # -- values
    def _value(self, where: str, v: Any, size: int | None, pic: str | None = None, usage: str = "DISPLAY") -> None:
        if isinstance(v, dict):
            h = v["hex"]
            if size is not None and len(h) != 2 * size:
                self.err(f"{where}: hex is {len(h) // 2} bytes, the field is {size}")
            return
        if pic and pic_info(pic)[0]:
            _n, signed, ip, dp, _ = pic_info(pic)
            try:
                dv = Decimal(v)
            except InvalidOperation:
                return self.err(f"{where}: {v!r} is not a number (PIC {pic})")
            if dv < 0 and not signed:
                self.err(f"{where}: negative value for unsigned PIC {pic}")
            sign, digits, exp = dv.as_tuple()
            scale = -exp if isinstance(exp, int) and exp < 0 else 0
            intdigits = len(str(abs(int(dv)))) if int(dv) else 0
            if scale > dp or intdigits > ip:
                self.err(f"{where}: {v!r} does not fit PIC {pic}")
            return
        try:
            b = v.encode("cp037")
        except UnicodeEncodeError:
            return self.err(f"{where}: {v!r} is not EBCDIC-037 text")
        if size is not None and len(b) > size:
            self.err(f"{where}: text is {len(b)} bytes, the area is {size}")

    def _area(self, where: str, a: Any) -> None:
        if a is None:
            return
        n = a["length"]
        if "text" in a:
            return self._value(where, a["text"], n)
        if "hex" in a:
            return self._value(where, {"hex": a["hex"]}, n)
        lay = self.layouts.get(a["layout"])
        if lay is None:
            return self.err(f"{where}: unknown layout {a['layout']!r}")
        for name, v in a["fields"].items():
            f = lay.get(name)
            if f is None or not f["elementary"]:
                self.err(f"{where}: layout {a['layout']} has no elementary field {name}")
                continue
            if f["offset"] + f["size"] > n:
                self.err(f"{where}: {name} ends at byte {f['offset'] + f['size']}, beyond length {n}")
            self._value(f"{where}.{name}", v, f["size"], f["pic"], f["usage"])
        for name, f in lay.items():
            if f["elementary"] and not f["optional"] and f["offset"] + f["size"] <= n and name not in a["fields"]:
                self.err(f"{where}: field {name} lies within length {n} but is not listed")

    # -- expected logs
    def _expected(self, sc: dict[str, Any], log: dict[str, Any], fname: str) -> None:
        if log["case"] != self.case["id"] or log["scenario"] != sc["id"]:
            self.err(f"expected/{fname}: case/scenario do not match")
        undefined = set(self.case.get("undefined_programs", []))
        for ti, task in enumerate(log["tasks"]):
            w = f"expected/{fname} task {task['seq']}"
            if task["seq"] != ti + 1:
                self.err(f"{w}: seq should be {ti + 1}")
            if task["transid"] not in self.transactions:
                self.err(f"{w}: transid {task['transid']} not in the CSD")
            elif self.transactions[task["transid"]] != task["program"]:
                self.err(f"{w}: transid {task['transid']} runs {self.transactions[task['transid']]}, not {task['program']}")
            trig = task["trigger"]
            if trig["kind"] == "terminal":
                if trig["step"] >= len(sc["steps"]):
                    self.err(f"{w}: trigger step {trig['step']} out of range")
                elif task["eibaid"] != sc["steps"][trig["step"]]["aid"]:
                    self.err(f"{w}: eibaid {task['eibaid']} is not step {trig['step']}'s aid")
            else:
                if trig["task"] > ti:
                    self.err(f"{w}: started by a later task")
                else:
                    evs = log["tasks"][trig["task"] - 1]["events"]
                    if trig["event"] >= len(evs) or evs[trig["event"]]["event"] != "START":
                        self.err(f"{w}: trigger does not name a START event")
            if task["commarea"] is None and task["eibcalen"] != 0:
                self.err(f"{w}: eibcalen {task['eibcalen']} with no commarea")
            if task["commarea"] is not None and task["commarea"]["length"] != task["eibcalen"]:
                self.err(f"{w}: commarea length is not eibcalen")
            self._area(f"{w} commarea", task["commarea"])
            last = task["events"][-1]
            if task["end"] == "normal" and not (last["event"] == "RETURN" and last["level"] == 1):
                self.err(f"{w}: end normal but the last event is not a level-1 RETURN")
            if task["end"] == "abend" and not (last["event"] == "ABEND" and last["outcome"] == "terminated"):
                self.err(f"{w}: end abend but the last event is not a terminating ABEND")
            for ei, ev in enumerate(task["events"]):
                self._event(f"{w} event {ei} ({ev['event']})", ev, undefined, ev is last)

    def _event(self, w: str, ev: dict[str, Any], undefined: set[str], is_last: bool) -> None:
        k = ev["event"]
        if ev["program"] not in self.programs:
            self.err(f"{w}: program {ev['program']} not in the CSD")
        if k in ("LINK", "XCTL"):
            if ev["target"] not in self.programs and ev["target"] not in undefined:
                self.err(f"{w}: target {ev['target']} is not defined")
            self._area(f"{w} commarea", ev["commarea"])
            if ev["commarea"] is not None and ev["commarea"]["length"] != ev["length"]:
                self.err(f"{w}: commarea length is not the LINK/XCTL length")
        if k == "RETURN":
            if ev["level"] == 1:
                if ev.get("transid") is not None and ev["transid"] not in self.transactions:
                    self.err(f"{w}: transid {ev['transid']} not in the CSD")
                if "caller_commarea" in ev:
                    self.err(f"{w}: caller_commarea only at level > 1")
                self._area(f"{w} commarea", ev.get("commarea"))
                if not is_last:
                    self.err(f"{w}: a level-1 RETURN must end the task")
            else:
                if "transid" in ev or "commarea" in ev:
                    self.err(f"{w}: transid/commarea only at level 1")
                self._area(f"{w} caller_commarea", ev.get("caller_commarea"))
        if k == "START":
            if ev["transid"] not in self.transactions:
                self.err(f"{w}: transid {ev['transid']} not in the CSD")
            if ("interval" in ev) == ("time" in ev):
                self.err(f"{w}: exactly one of interval / time")
            self._area(f"{w} from", ev["from"])
        if k in ("RETRIEVE", "READQ-TS", "RECEIVE"):
            self._area(f"{w} data", ev["data"])
        if k == "WRITEQ-TS":
            self._area(f"{w} data", ev["data"])
        if k == "READ" and ev["file"] not in self.files_csd:
            self.err(f"{w}: file {ev['file']} not in the CSD")
        if k == "ABEND":
            if ev["cause"] == "condition" and "condition" not in ev:
                self.err(f"{w}: cause condition needs 'condition'")
            if (ev["outcome"] == "exit") != ("exit" in ev):
                self.err(f"{w}: 'exit' goes with outcome exit")
        if k in ("SEND-MAP", "RECEIVE-MAP"):
            info = self.bms.get(ev["map"])
            if info is None:
                return self.err(f"{w}: no map {ev['map']}")
            if info["mapset"] != ev["mapset"]:
                self.err(f"{w}: map {ev['map']} is in mapset {info['mapset']}")
        if k == "SEND-MAP":
            self._send_map(w, ev, self.bms[ev["map"]])

    def _send_map(self, w: str, ev: dict[str, Any], info: dict[str, Any]) -> None:
        named = {f["name"]: f for f in info["fields"]}
        opts = ev["options"]
        if opts != sorted(opts):
            self.err(f"{w}: options must be sorted")
        for n in named:
            if n not in ev["fields"] and "DATAONLY" not in opts:
                self.err(f"{w}: field {n} missing (only DATAONLY may omit fields)")
        if isinstance(ev.get("cursor"), str) and ev["cursor"] not in named:
            self.err(f"{w}: cursor field {ev['cursor']} not in map")
        for n, f in ev["fields"].items():
            fw = f"{w} field {n}"
            if n not in named:
                self.err(f"{fw}: not a named field of {ev['map']}")
                continue
            d = named[n]
            if (f["attr"] is None) != (f["attr_from"] == "none"):
                self.err(f"{fw}: attr null exactly when attr_from is none")
            if f["attr_from"] == "none" and "DATAONLY" not in opts:
                self.err(f"{fw}: attr_from none only under DATAONLY")
            if "MAPONLY" in opts and "program" in (f["attr_from"], f["data_from"]):
                self.err(f"{fw}: MAPONLY takes nothing from the program")
            if f["attr"] is not None:
                b = int(f["attr"], 16)
                if f["attr_from"] == "map":
                    want = attrb_byte(d["attrb"], d["has_attrb"])
                    if b != want:
                        self.err(f"{fw}: map attr should be {want:02X} (ATTRB={d['attrb']})")
                if b in (0x00, 0x80, 0x02, 0x82) and f["attr_from"] == "program":
                    self.err(f"{fw}: {f['attr']} is never taken from the program")
                if "meaning" in f and f["meaning"] != attr_meaning(b):
                    self.err(f"{fw}: meaning {f['meaning']} disagrees with {f['attr']} ({attr_meaning(b)})")
            if (f["data"] is None) != (f["data_from"] == "none"):
                self.err(f"{fw}: data null exactly when data_from is none")
            if f["data"] is not None:
                self._value(f"{fw} data", f["data"], d["length"])
            for x in ("color", "hilight"):
                if x in f and not info["dsatts"]:
                    self.err(f"{fw}: {x} on a map without DSATTS")

    def _notes(self) -> None:
        p = self.dir / "NOTES.md"
        if not p.is_file():
            return self.err("no NOTES.md")
        text = p.read_text(encoding="utf-8")
        heads = [h.strip() for h in re.findall(r"^##\s+(.+)$", text, re.M)]
        for s in NOTES_SECTIONS:
            if s not in heads:
                self.err(f"NOTES.md: no '## {s}' section")
        if "ibm.com" not in text and not re.search(r"\b(SC|GA|SA)\d{2}-\d{4}", text):
            self.err("NOTES.md: cites no IBM document")


def main(argv: list[str]) -> int:
    targets = [Path(a).resolve() for a in argv] or sorted(p.parent for p in (ROOT / "cases").glob("*/*/case.json"))
    if not targets:
        print("no cases found")
        return 1
    bad = 0
    for d in targets:
        problems = Case(d).run()
        rel = d.relative_to(ROOT) if d.is_relative_to(ROOT) else d
        if problems:
            bad += 1
            for p in problems:
                print(f"{rel}: {p}")
        else:
            print(f"{rel}: ok")
    print(f"{len(targets) - bad}/{len(targets)} cases valid")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
