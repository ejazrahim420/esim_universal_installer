## 1.0.0

* Initial release of `esim_universal_installer`.
* Direct eSIM installation on iOS via Apple Universal Link provisioning URLs (iOS 17.4+).
* Direct eSIM installation on Android via Android eSIM provisioning URLs.
* Compatibility checks via [`esim_compatibility`](https://pub.dev/packages/esim_compatibility):
  * Android: `EuiccManager.isEnabled()`
  * iOS: `UIDevice` model compared to a known eSIM-supported device list (**not confirmed**; `isConfirmed: false`)
* Input validation, typed exceptions, and an example application.
