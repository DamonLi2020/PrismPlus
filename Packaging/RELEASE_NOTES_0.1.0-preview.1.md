# Prism Plus 0.1.0 Preview 1

This is the first public preview of Prism Plus, a local-first native macOS LaTeX editor.

## Read before downloading

- This is prerelease software intended for evaluation and feedback.
- The build is ad-hoc signed and **not notarized by Apple**. macOS will display a developer
  verification warning.
- It requires an Apple-silicon Mac (M1 or newer) running macOS 14 or newer. Intel Macs are not
  supported by this build.
- Back up important LaTeX projects before testing file-management functionality.
- Download only from this official GitHub repository and verify `SHA256SUMS.txt` before bypassing
  any operating-system warning.

## Install

1. Download `PrismPlus-0.1.0-arm64.dmg` and `SHA256SUMS.txt`.
2. Optionally verify the download in Terminal:

   ```sh
   cd ~/Downloads
   shasum -a 256 PrismPlus-0.1.0-arm64.dmg
   ```

   Confirm that the result matches the DMG entry in `SHA256SUMS.txt`.
3. Open the DMG and drag **Prism Plus** into **Applications**.
4. In Applications, Control-click **Prism Plus**, choose **Open**, and confirm.
5. If it remains blocked, verify the checksum first, then use **System Settings → Privacy &
   Security → Open Anyway**.

Do not disable Gatekeeper globally and do not remove quarantine protection from a copy downloaded
from another source.

## Included in this preview

- Monaco-powered LaTeX editing, completion, snippets, pairing, and formatting
- Live Tectonic compilation and stable PDFKit preview
- Project explorer with inline file and folder management
- Document outline with click-to-jump navigation
- Clickable diagnostics and red/yellow source markers
- PDF download and export beside the source document
- Bundled Tectonic compiler and runtime licenses

## Privacy and network behavior

Documents stay on the Mac. The editor UI loads from the app bundle rather than a CDN. Tectonic may
download TeX support files on first use or when a document requests an uncached package, then
reuses its local cache. Compilation runs in Tectonic untrusted mode.

Please report bugs through the repository's Issues tab with your Mac model, macOS version,
reproduction steps, expected result, actual result, and a screenshot when useful.
