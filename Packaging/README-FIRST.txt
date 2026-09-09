Prism Plus 0.1.0 — Friend Prototype
====================================

System requirements
-------------------
- An Apple-silicon Mac (M1, M2, M3, M4, or newer)
- macOS 14 Sonoma or newer
- Internet access the first time a LaTeX document uses packages that Tectonic has not cached

Install
-------
1. Open the DMG.
2. Drag Prism Plus into Applications.
3. In Applications, Control-click Prism Plus and choose Open.
4. Confirm Open if macOS warns that this is an app from an unidentified developer.

This prototype is ad-hoc signed because it is not yet distributed through Apple's Developer ID
and notarization service. If macOS still blocks it, the sender can provide a fresh build or the
recipient can remove the downloaded-file quarantine in Terminal:

    xattr -dr com.apple.quarantine "/Applications/Prism Plus.app"

Privacy and operation
---------------------
- Documents stay on the Mac.
- PDF compilation uses the Tectonic engine bundled inside the app.
- Tectonic may download TeX support files on first use, then reuses its local cache.
- Compilation always runs in Tectonic's untrusted mode.

Please do not treat this prototype as a notarized public release. Back up important LaTeX projects
before testing file-management features.

Feedback
--------
Please see FRIEND-FEEDBACK.md in this disk image.
