# Contributing

Use Xcode 26+, XcodeGen and Python 3. On nix-darwin, add `pkgs.xcodegen` to your
configuration. `project.yml` defines the project; generated Xcode files are ignored.

Before submitting changes:

```sh
scripts/test.sh
python3 scripts/check-publication.py
git diff --check
```

Tests use temporary settings without opening browsers or changing login items.
For native picker interaction checks, run `PICKOSAURUS_MENU_SMOKE=1 scripts/test.sh`.
Check UI and link-opening changes in the debug app too.

Keep changes small, fast and private. Preserve MIT notices, document artwork
sources, and keep credentials and build products out of commits.
See [security reporting](SECURITY.md) for vulnerabilities and
[maintainer notes](docs/maintaining.md) for releases.
