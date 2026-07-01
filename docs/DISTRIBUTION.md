# Distribution

Cursor Flock preview builds are distributed through GitHub Releases only.

The preview build is ad-hoc signed only. It is not signed with a paid Apple Developer ID certificate and is not notarized by Apple.

Because the build is not Developer ID signed or notarized, macOS may require manual approval through System Settings > Privacy & Security on first launch. Users should not disable Gatekeeper globally.

## Verify SHA-256

After downloading the DMG and its `.sha256` file from GitHub Releases, run:

```sh
shasum -a 256 -c CursorFlock-VERSION-macos.dmg.sha256
```

Replace `VERSION` with the release version. A successful verification prints `OK`.

The checksum confirms that the downloaded DMG matches the file produced for the release. It does not make the build notarized or Apple verified.
