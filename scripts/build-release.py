#!/usr/bin/env python3
"""Create a source-only ZIP from locally reviewed publication candidates."""

import hashlib
import importlib.util
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("audit", ROOT / "scripts/validate-source.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)
files = audit.source_files()
audit.validate(files)
destination = ROOT / "dist"
destination.mkdir(exist_ok=True)
archive = destination / "zabbix-obs-source.zip"
expected = []
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
    for path in files:
        name = "zabbix-obs/" + path.relative_to(ROOT).as_posix()
        expected.append(name)
        # All allowed inputs are text; preserve LF for direct use after extraction
        # even when the workstation originally checked out CRLF files.
        info = zipfile.ZipInfo(name)
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = (0o100755 if path.suffix == ".sh" else 0o100644) << 16
        bundle.writestr(info, path.read_text(encoding="utf-8").encode("utf-8"))
with zipfile.ZipFile(archive) as bundle:
    assert bundle.namelist() == expected
    assert bundle.testzip() is None
print(f"Created {archive} ({len(files)} source files)")
print(f"SHA256 {hashlib.sha256(archive.read_bytes()).hexdigest()}")
