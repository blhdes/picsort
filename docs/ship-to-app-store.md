# Ship picsort to the App Store

## Context

The app's features are complete. This plan covers the remaining technical gaps that would block or weaken an App Store submission. Some items are code changes I can make; others require your action (icon design, privacy policy hosting, screenshots).

## Blockers (must fix before submission)

### 1. Missing `NSPhotoLibraryAddUsageDescription`

The app creates albums, adds photos to albums, and deletes photos — all write operations. Apple **will reject** without this key.

| File | Change |
|------|--------|
| `picsort.xcodeproj/project.pbxproj` | Add `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription` build setting |

Suggested text: *"picsort creates albums and organizes photos in your library based on your sorting choices."*

### 2. App Icon (you need to provide this)

`Assets.xcassets/AppIcon.appiconset/` is empty. You need a **1024x1024 PNG** — Xcode 15+ auto-generates all other sizes from it.

### 3. Privacy Policy (you need to host this)

Apple requires a privacy policy URL in your App Store listing. Since picsort accesses the photo library and stores sorting data on-device (SwiftData), the policy should state:

- Photos are accessed and organized locally on the device
- No data leaves the device — no cloud, no analytics, no tracking
- SwiftData stores sorting metadata only (asset identifiers, gallery names)

## Recommended improvements

### 4. Set an AccentColor — soft teal

`Assets.xcassets/AccentColor.colorset/` is empty. The app uses system blue by default. A **soft teal** (`#3AAFA9` light / `#5CC8C3` dark) gives picsort its own identity without clashing with the swipe overlay colors (red, gold, blue).

| File | Change |
|------|--------|
| `picsort/Assets.xcassets/AccentColor.colorset/Contents.json` | Define teal color with light + dark variants |

### 5. Fix deployment target mismatch

README says iOS 17.0+, but `project.pbxproj` sets `IPHONEOS_DEPLOYMENT_TARGET = 17.6`. Either:
- Lower to 17.0 (broader reach, everything used is available in 17.0)
- Update README to say 17.6 (if you want to require it)

| File | Change |
|------|--------|
| `picsort.xcodeproj/project.pbxproj` | Change deployment target to `17.0` |

### 6. Onboarding / first-launch experience

Right now if a user denies photo access, they see an empty screen. A brief explanation or a "go to Settings" prompt would help.

| File | Change |
|------|--------|
| `picsort/Views/DatePickerView.swift` | Add a denied-permission state with instructions |

---

## Code changes (Claude can do)

1. Add `NSPhotoLibraryAddUsageDescription` to build settings
2. Set AccentColor (soft teal)
3. Lower deployment target to 17.0
4. Add a permission-denied state to DatePickerView

## Manual tasks (you need to handle)

1. App icon (1024x1024 PNG)
2. Privacy policy (hosted URL)
3. App Store screenshots (3-5 per device size)
4. App Store description, keywords, category
5. Apple Developer account & provisioning

## Verification

1. Build with no warnings
2. Archive succeeds
3. App icon visible on home screen and in Settings
4. Photo library permission prompt shows both read and write descriptions
5. Denying permission shows helpful message instead of blank screen
