#!/usr/bin/env python3
"""Read-only checks for files eligible for the next commit; never print secret values."""
import json
import pathlib
import plistlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from urllib.parse import unquote, urlsplit

ROOT = pathlib.Path(__file__).resolve().parent.parent
names = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=ROOT
).decode().split("\0")
files = sorted({name for name in names if name and (ROOT / name).is_file()})
failures = []

def fail(message):
    failures.append(message)

license_text = (ROOT / "LICENSE.md").read_bytes()
if license_text != (ROOT / "Pickosaurus/Resources/LICENSE.txt").read_bytes():
    fail("Source and bundled MIT notices differ")
if b"Copyright (c) 2026 Mert IZCI" not in license_text:
    fail("Original copyright notice is missing")
for required in ["README.md", "PRIVACY.md", "LICENSING.md", "CONTRIBUTING.md", "Pickosaurus/Resources/NOTICES.txt"]:
    if not (ROOT / required).is_file():
        fail(f"Missing publication file: {required}")

# A broad ignore pattern can hide an entire source directory on a case-insensitive Mac.
source_types = {".swift", ".plist", ".entitlements", ".json", ".png", ".txt", ".html", ".md", ".svg"}
for source in (ROOT / "Pickosaurus").rglob("*"):
    if source.is_file() and source.suffix in source_types and source.relative_to(ROOT).as_posix() not in files:
        fail(f"Required source/asset is excluded from publication: {source.relative_to(ROOT)}")

old_brand = re.compile(rb"browser[ _-]?picker", re.I)
secrets = re.compile(
    rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"
    rb"|\bgh[pousr]_[A-Za-z0-9]{30,}\b"
    rb"|\bgithub_pat_[A-Za-z0-9_]{40,}\b"
    rb"|\bAKIA[A-Z0-9]{16}\b"
    rb"|\bxox[baprs]-[A-Za-z0-9-]{20,}\b"
)
for name in files:
    path = ROOT / name
    parts = pathlib.PurePosixPath(name).parts
    if parts[0] in {"build", "DerivedData", ".build"} or any(p.endswith(".xcodeproj") for p in parts):
        fail(f"Generated output eligible for publication: {name}")
    if path.suffix.lower() in {".p12", ".pfx", ".p8", ".key", ".mobileprovision", ".provisionprofile"} or path.name.startswith(".env") and path.name != ".env.example":
        fail(f"Credential-shaped file eligible for publication: {name}")
    content = path.read_bytes()
    if secrets.search(content):
        fail(f"Possible credential in {name} (value withheld)")
    if b"\0" in content:
        continue
    if name != "README.md" and old_brand.search(content):
        fail(f"Former product branding outside README attribution: {name}")
    if path.suffix == ".md":
        for match in re.finditer(r"\]\(([^)\s]+)\)", content.decode("utf-8")):
            link = match.group(1).strip("<>")
            parsed = urlsplit(link)
            if parsed.scheme or link.startswith(("#", "//")) or not parsed.path:
                continue
            if not (path.parent / unquote(parsed.path)).exists():
                fail(f"Broken local documentation link in {name}: {link}")
    if path.name == "Contents.json":
        for item in json.loads(content).get("images", []):
            if item.get("filename") and not (path.parent / item["filename"]).is_file():
                fail(f"Missing asset in {name}: {item['filename']}")
    if path.name == "icon.json" and path.parent.suffix == ".icon":
        for group in json.loads(content).get("groups", []):
            for layer in group.get("layers", []):
                image_name = layer.get("image-name")
                if image_name and not (path.parent / "Assets" / image_name).is_file():
                    fail(f"Missing Icon Composer asset in {name}: {image_name}")

for svg in (ROOT / "Pickosaurus").rglob("*.svg"):
    if svg.relative_to(ROOT).as_posix() != "Pickosaurus/AppIcon.icon/Assets/Dinosaur.svg":
        fail("Review SVG artwork provenance before bundling new icons")
        continue
    # The reviewed dinosaur is original vector geometry derived from our own logo.
    # Keep the master self-contained: no raster embeds, scripts or external files.
    allowed_tags = {"svg", "title", "desc", "defs", "linearGradient", "stop", "g", "path", "ellipse"}
    for element in ET.parse(svg).iter():
        if element.tag.rsplit("}", 1)[-1] not in allowed_tags:
            fail(f"Unsupported element in vector master: {element.tag}")
        for key, value in element.attrib.items():
            if key.rsplit("}", 1)[-1].lower().startswith("on") or "href" in key.lower():
                fail("Vector master must not contain event handlers or resource links")
            if "url(" in value and not re.fullmatch(r"url\(#[A-Za-z0-9_-]+\)", value):
                fail("Vector master must only reference local gradients")
# Keep the app free of the removed privileged browser integrations.
forbidden = re.compile(r"import WebKit|WKWebView|BrowserIconImporter|browserIcons|customIconData|AXUIElement|AXIsProcessTrusted|NSAppleScript|osascript|AEDeterminePermissionToAutomateTarget|SFAuthorization|SMJobBless|AuthorizationExecuteWithPrivileges|addGlobalMonitorForEvents|SafariProfile|ProfileDiscovery|MozLz4|sqlite3_|com\.apple\.security\.automation|NSAppleEventsUsageDescription")
for path in (ROOT / "Pickosaurus").rglob("*"):
    if path.suffix in {".swift", ".plist", ".entitlements"} and forbidden.search(path.read_text()):
        fail(f"Removed permission/browser-data capability reintroduced: {path.relative_to(ROOT)}")
entitlements = plistlib.loads((ROOT / "Pickosaurus/Pickosaurus.entitlements").read_bytes())
if list((ROOT / "Pickosaurus/Resources").glob("*.html")):
    fail("Help should be bundled native text, not HTML")
if entitlements:
    fail("Review new app entitlements before publication")

if failures:
    print("\n".join("FAIL: " + item for item in failures))
    sys.exit(1)
print(f"PASS: {len(files)} publication files checked; MIT notices agree, local links/assets resolve, and no credential patterns or generated products found")
print("This pattern scan is not proof of secret absence or legal clearance; review LICENSING.md and the diff before publishing.")
