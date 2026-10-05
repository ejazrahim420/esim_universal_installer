# esim_universal_installer

Install eSIMs from Flutter by opening the official **Apple** and **Android** eSIM provisioning Universal Links.

Compatibility detection is powered by [`esim_compatibility`](https://pub.dev/packages/esim_compatibility).

This package starts the system eSIM setup flow using a provisioning URL. It does **not** download profiles itself through carrier privileged APIs.

> **Package name:** `esim_universal_installer`  
> Available for publishing on [pub.dev](https://pub.dev). The shorter name `esim_installer` is already taken.

## Features

- Direct eSIM installation on **iOS** (Universal Link, iOS 17.4+)
- Direct eSIM installation on **Android** (provisioning URL)
- eSIM compatibility checks via [`esim_compatibility`](https://pub.dev/packages/esim_compatibility)
- Null-safe Dart API with validation and typed exceptions
- Example application demonstrating install + compatibility

## Requirements

### Android

- **Minimum OS/API for this package's install flow:** Android 10 / API 29+
- Device must have **eSIM / eUICC hardware**
- Embedded subscriptions must be **enabled/available**
- Android 10+ alone does **not** mean every phone supports eSIM

Compatibility on Android uses `esim_compatibility`, which checks `EuiccManager.isEnabled()`.

### iOS

- **Universal Link provisioning:** iOS 17.4+
- Device and carrier configuration must support eSIM
- iOS 17.4+ alone does **not** mean every iPhone supports eSIM

#### iOS compatibility (important)

Compatibility on iOS is provided by [`esim_compatibility`](https://pub.dev/packages/esim_compatibility), which:

- Detects the device model (`UIDevice`)
- Compares against a list of known eSIM-supported Apple devices
- Uses logic that matches the iOS implementation in that package

**This iOS check is NOT confirmed** (`isConfirmed: false`).

Apple does **not** provide a reliable public API for third-party apps to determine whether a device currently supports eSIM (there is no `EuiccManager`-equivalent). A `supported` / `unsupported` result on iOS means the device model matched (or did not match) a known list — it is **not** an authoritative system confirmation.

Treat iOS compatibility as a best-effort hint. Always allow install attempts to fail gracefully based on system / carrier behavior.

### Unsupported platforms

Web, Windows, macOS, and Linux are not supported for eSIM installation. Calls fail with `EsimUnsupportedPlatformException` (or return `unsupported` from compatibility checks).

## Installation

```yaml
dependencies:
  esim_universal_installer: ^1.0.0
```

Then run:

```bash
flutter pub get
```

This package depends on [`esim_compatibility`](https://pub.dev/packages/esim_compatibility) and `url_launcher`.

## Usage

```dart
import 'package:esim_universal_installer/esim_universal_installer.dart';

final esim = EsimUniversalInstaller();
```

### Android installation

Pass the full LPA activation string (typically from a QR payload):

```dart
try {
  final result = await esim.install(
    lpa: r'LPA:1$smdp.example.com$MATCHING-ID',
  );
  print('Opened: ${result.provisioningUrl}');
} on EsimException catch (error) {
  print(error);
}
```

This opens:

```text
https://esimsetup.android.com/esim_qrcode_provisioning?carddata=<LPA>
```

### iOS installation

Pass SM-DP+ address and matching ID:

```dart
try {
  final result = await esim.install(
    smdp: 'smdp.example.com',
    matchingId: 'MATCHING-ID',
  );
  print('Opened: ${result.provisioningUrl}');
} on EsimException catch (error) {
  print(error);
}
```

This opens:

```text
https://esimsetup.apple.com/esim_qrcode_provisioning?carddata=LPA:1$SM-DP+ADDRESS$MATCHING_ID
```

Platform-specific helpers:

```dart
await esim.installOnAndroid(lpa: lpa);
await esim.installOnIos(smdp: smdp, matchingId: matchingId);
```

### Compatibility check

```dart
final compatibility = await esim.checkCompatibility();

print(compatibility.status);       // supported | unsupported | unknown
print(compatibility.isConfirmed);  // true on Android, false on iOS
print(compatibility.details);

// Convenience: true only when status == supported
final supported = await esim.isEsimSupported();
```

#### Android behavior

Delegates to [`esim_compatibility`](https://pub.dev/packages/esim_compatibility):

- Uses native `EuiccManager.isEnabled()`
- Result is treated as a runtime platform check (`isConfirmed: true`)

#### iOS behavior

Delegates to [`esim_compatibility`](https://pub.dev/packages/esim_compatibility):

- Detects the device model (`UIDevice`)
- Compares against a list of known eSIM-supported Apple devices
- Result is marked `isConfirmed: false`
- **Not confirmed** — do not treat as authoritative Apple API confirmation

## Error handling

| Exception | When |
| --- | --- |
| `EsimValidationException` | Missing/invalid `smdp`, `matchingId`, or `lpa` |
| `EsimUnsupportedPlatformException` | Web/desktop, or wrong platform-specific helper |
| `EsimLaunchException` | Provisioning URL could not be opened |
| `EsimPlatformException` | Unexpected platform/plugin failures (if surfaced) |

```dart
try {
  await esim.install(lpa: lpa);
} on EsimValidationException catch (e) {
  // Fix inputs
} on EsimUnsupportedPlatformException catch (e) {
  // Show platform message
} on EsimLaunchException catch (e) {
  // URL could not be opened
} on EsimException catch (e) {
  // Any package error
}
```

## Platform limitations

| Topic | Android | iOS |
| --- | --- | --- |
| Install mechanism | Provisioning URL via `url_launcher` | Apple Universal Link via `url_launcher` |
| Min feature OS | API 29+ | iOS 17.4+ |
| Compatibility source | `esim_compatibility` → `EuiccManager` | `esim_compatibility` → `UIDevice` model list |
| Confirmed? | Yes — `EuiccManager` runtime check (`isConfirmed: true`) | **No** — device-model list only (`isConfirmed: false`) |
| Hardware guarantee | No — API 29 ≠ eSIM hardware | No — iOS 17.4 / model list ≠ guaranteed eSIM |

Opening a provisioning URL **initiates** the system UI. Success still depends on device hardware, carrier support, profile state, and user confirmation.

## Permissions / configuration

### Android

No special dangerous permissions are required for this Universal Link approach.

Consuming apps should target devices on Android 10+ for the install flow.

`url_launcher` opens the URL with `LaunchMode.externalApplication`.

### iOS

No custom entitlement is required for opening Apple's provisioning Universal Link.

The URL is opened externally (outside an in-app web view), which is required for the eSIM flow.

## Example app

```bash
cd example
flutter run
```

The example shows:

- Platform information
- Compatibility status (including `isConfirmed` note on iOS)
- SM-DP+ / Matching ID fields on iOS
- LPA field on Android
- Install action with success/error messages

Sample activation values in the example are **placeholders only**.

## API overview

```dart
final esim = EsimUniversalInstaller();

await esim.checkCompatibility(); // via esim_compatibility
await esim.isEsimSupported();
await esim.install(lpa: '...');                      // Android
await esim.install(smdp: '...', matchingId: '...');  // iOS

const builder = EsimProvisioningUrlBuilder();
builder.buildIosUrl(smdp: '...', matchingId: '...');
builder.buildAndroidUrl(lpa: '...');
```

## Related package

- [`esim_compatibility`](https://pub.dev/packages/esim_compatibility) — Android `EuiccManager` + iOS `UIDevice` model-list detection used by this package

## License

MIT License. See [LICENSE](LICENSE).
# esim_universal_installer
