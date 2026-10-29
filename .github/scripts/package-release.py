"""Package a built FiveM resource with the release tag's manifest version."""
import re
import sys
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

root = Path(__file__).resolve().parents[2]
tag = sys.argv[1]
if not re.fullmatch(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", tag):
    raise SystemExit("Expected a stable version tag such as v1.0.0")
if not (root / "html/dist/index.html").is_file():
    raise SystemExit("Build the UI before packaging")
manifest, count = re.subn(
    r'(?m)^version\s+[\"\'][^\"\']+[\"\']',
    f'version "{tag[1:]}"',
    (root / "fxmanifest.lua").read_text(encoding="utf-8"),
)
if count != 1:
    raise SystemExit("Expected exactly one manifest version")
output = root / "release" / f"tss_bridge-{tag}.zip"
output.parent.mkdir(exist_ok=True)
with ZipFile(output, "w", ZIP_DEFLATED) as archive:
    archive.writestr("tss_bridge/fxmanifest.lua", manifest)
    archive.write(root / "README.md", "tss_bridge/README.md")
    for folder in ("shared", "modules", "client", "server", "bridge_lab", "html/dist"):
        for path in sorted((root / folder).rglob("*")):
            if path.is_file():
                archive.write(path, "tss_bridge/" + path.relative_to(root).as_posix())
print(output)
