# Ship Culla to the App Store

## Remaining tasks (you need to handle)

### 1. Privacy Policy (hosted URL)

Apple requires a privacy policy URL in your App Store listing. Since Culla accesses the photo library and stores sorting data on-device (SwiftData), the policy should state:

- Photos are accessed and organized locally on the device
- No data leaves the device — no cloud, no analytics, no tracking
- SwiftData stores sorting metadata only (asset identifiers, gallery names)

### 2. App Store screenshots (3-5 per device size)

### 3. App Store description, keywords, category

### 4. Apple Developer account & provisioning

## Verification

1. Build with no warnings
2. Archive succeeds
3. App icon visible on home screen and in Settings
4. Photo library permission prompt shows both read and write descriptions
5. Denying permission shows helpful message instead of blank screen
