/// Whether the current device appears to support eSIM.
///
/// Results come from [`esim_compatibility`](https://pub.dev/packages/esim_compatibility):
/// - **Android:** `EuiccManager.isEnabled()` (more reliable runtime check)
/// - **iOS:** device-model check via `UIDevice` (not confirmed)
enum EsimSupportStatus {
  /// The compatibility check reported that eSIM appears available.
  ///
  /// On iOS this is based on a known-device model list and is **not confirmed**
  /// (`isConfirmed: false`).
  supported,

  /// The compatibility check reported that eSIM does not appear available.
  ///
  /// On iOS this is based on a known-device model list and is **not confirmed**
  /// (`isConfirmed: false`).
  unsupported,

  /// eSIM support could not be determined (for example on unsupported
  /// platforms, or when the compatibility plugin call fails).
  unknown,
}
