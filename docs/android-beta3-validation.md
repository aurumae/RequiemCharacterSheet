# Android beta 3 validation

Prepared **1.0.0-beta.3 (11)**; the user confirmed Play's latest code is 10.
Implementation: `0ca595d` (parity/CI), `ad6bc35` (separate shared core).
PR: https://github.com/aurumae/RequiemCharacterSheet/pull/7

## Automated acceptance

- Strict and supported-mode Swift/Kotlin real-store exchange pass: 275 Swift producer
  cases, 68 Requiem JVM cases, 11 Android storage cases, 3 independent core cases and
  6 Swift consumers. One producer-only consumer test is exercised in the later phase.
- All 11 CI-policy tests pass. Eight books and 15 shared scenarios; no declared pending
  Requiem capabilities. Historical fixtures remain unchanged, and newer saves are
  rejected without modifying files. CI declarations require passing test evidence.
- All 26 emulator UI/upgrade cases pass together (API 36.1, 4 KB kernel). Normal,
  150% text and landscape reference captures reviewed locally; final captures also
  include Attributes and Merits. Picker IME dismissal and activity recreation covered.
- Five canonical v10/v11/v12 fixtures produce byte-identical JSON before/after core
  extraction. An in-place **debug code 10 → 11** update preserves four ordinary,
  guided, Conditions and elder-bane files through real-store open, unchanged save
  and export. Dates, IDs, tracks and paid-dot history are preserved.
- Debug/test/release builds and debug/release lint pass (zero lint errors).
- Signed AAB validates with bundletool; AAB/APK signatures verify with the existing
  upload certificate. Bundle requests 16 KB alignment; ZIP and all native ELF load
  segments pass static 16 KB checks. Jarsigner reports the expected self-signed trust
  and missing-timestamp warnings, plus AGP's manifest placement/JarInputStream warning;
  its JarFile signature verification succeeds.

The first GitHub exchange run exposed macOS Bash 3.2 empty-array handling; the script
was corrected and report artifact uploads include the hidden report directory.
Live checks are on the PR. GitHub's iOS UI-test skip remains; Xcode Cloud/local iOS
UI coverage is separate. Main has no branch protection; no setting was changed.

## Local release artifacts

`/home/oisin/RequiemCharacterSheetApp/AndroidBuilds/ad6bc35/` contains the signed AAB,
upload-signed verification APK, debug APK, SHA256SUMS, build-info.json, release notes
and validation evidence. Screenshots remain local. The package/application/storage
identity is unchanged. No Play upload, rollout or tester notification has occurred.

AAB SHA-256:
`d7488ca1822f2a546922a11b65e27e6c1dfb7f77763e05cc781f598d5ccd6412`

## Remaining release acceptance

Record S24 FE testing, TalkBack traversal, real-device iOS file exchange, the
Play-delivered signed update and actual 16 KB runtime checks before claiming full
physical-device parity. Local debug upgrade and static alignment checks do not
establish these. Existing Play/privacy/backup review items remain in the release
guide. No Forsaken features, PDF export or Tilts were added.
