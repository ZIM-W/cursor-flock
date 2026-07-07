# Release Process

Run these commands from the repository root:

```sh
export VERSION="0.1.0"
chmod +x scripts/*.sh
./scripts/build_release.sh
./scripts/adhoc_sign_app.sh
./scripts/create_dmg.sh
./scripts/verify_release.sh
./scripts/generate_checksums.sh
./scripts/create_github_release_notes.sh
```

The release artifacts are written to `release-output/$VERSION/`:

- `CursorFlock-VERSION-macos.dmg`
- `CursorFlock-VERSION-macos.dmg.sha256`
- `CursorFlock-VERSION-release-notes.md`

## Manual GitHub Publishing

1. Create and push a tag:

```sh
git tag v0.1.0
git push origin v0.1.0
```

2. Open GitHub repository → Releases.
3. Select “Draft a new release”.
4. Choose v0.1.0.
5. Use title:

```text
Cursor Flock v0.1.0
```

6. Mark it as a pre-release.
7. Upload files from `release-output/0.1.0/`:
    * CursorFlock-0.1.0-macos.dmg
    * CursorFlock-0.1.0-macos.dmg.sha256
8. Paste `release-output/0.1.0/CursorFlock-0.1.0-release-notes.md`.
9. Publish the release.

This workflow does not use Apple notarization, Developer ID signing, GitHub APIs, or GitHub CLI.
