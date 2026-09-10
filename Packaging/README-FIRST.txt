Prism Plus 0.1.0 — Friend Prototype
====================================

System requirements
-------------------
- An Apple-silicon Mac (M1, M2, M3, M4, or newer)
- macOS 14 Sonoma or newer
- Internet access the first time a LaTeX document uses packages that Tectonic has not cached

Download safety
---------------
- Use the official release page: https://github.com/DamonLi2020/PrismPlus/releases
- This preview is ad-hoc signed and is not notarized by Apple.
- Check SHA256SUMS.txt before bypassing a macOS warning.
- Back up important LaTeX projects before testing file-management features.

Install
-------
1. Open the DMG.
2. Drag Prism Plus into Applications.
3. In Applications, Control-click Prism Plus and choose Open.
4. Confirm Open if macOS warns that this is an app from an unidentified developer.

This prototype is ad-hoc signed because it is not yet distributed through Apple's Developer ID
and notarization service. If macOS still blocks it, first confirm that the download came from the
official release page and that its checksum matches. Then open System Settings > Privacy &
Security and choose Open Anyway.

Do not remove macOS quarantine protection from a file obtained from any other source.

Privacy and operation
---------------------
- Documents stay on the Mac.
- PDF compilation uses the Tectonic engine bundled inside the app.
- Tectonic may download TeX support files on first use, then reuses its local cache.
- Compilation always runs in Tectonic's untrusted mode.

Please do not treat this preview as a notarized production release.

Feedback
--------
Please see FRIEND-FEEDBACK.md in this disk image.
