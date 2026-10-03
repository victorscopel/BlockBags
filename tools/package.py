"""Build a distributable addon ZIP without git files, tests or character data."""
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
toc_path = ROOT / "BlockBags.toc"
toc = toc_path.read_text(encoding="utf-8-sig")
match = re.search(r"^## Version:\s*([\w.\-]+)\s*$", toc, re.MULTILINE)
if not match:
    raise SystemExit("TOC has no valid version")
version = match.group(1)
files = {toc_path, ROOT / "Bindings.xml", ROOT / "README.md", ROOT / "LICENSE", ROOT / "THIRD_PARTY_NOTICES.md"}
for line in toc.splitlines():
    entry = line.strip()
    if not entry or entry.startswith("#"):
        continue
    path = (ROOT / entry.replace("\\", "/")).resolve()
    if not path.is_relative_to(ROOT) or not path.is_file():
        raise SystemExit(f"Invalid TOC entry: {entry}")
    files.add(path)
for path in files:
    if not path.is_file():
        raise SystemExit(f"Required release file missing: {path.name}")
out = ROOT / "dist"
out.mkdir(exist_ok=True)
target = out / f"BlockBags-{version}.zip"
with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(files):
        relative = path.relative_to(ROOT).as_posix()
        archive.writestr(f"BlockBags/{relative}", path.read_bytes())
with zipfile.ZipFile(target) as archive:
    assert archive.testzip() is None
    assert "BlockBags/BlockBags.toc" in archive.namelist()
    assert all(name.startswith("BlockBags/") for name in archive.namelist())
print(f"Built {target.name}: {len(files)} files, {target.stat().st_size} bytes")
