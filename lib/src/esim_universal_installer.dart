import 'dart:io' show Platform;

import 'package:esim_compatibility/esim_compatibility.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

import 'exceptions/esim_exception.dart';
import 'models/esim_compatibility_result.dart';
import 'models/esim_install_result.dart';
import 'models/esim_support_status.dart';
import 'provisioning_url_builder.dart';

/// Signature used to open a provisioning URL externally.
typedef EsimUrlLauncher = Future<bool> Function(
  Uri url, {
  LaunchMode mode,
});

/// Signature used to query device eSIM compatibility.
///
/// Defaults to [EsimCompatibility.isEsimCompatible] from the
/// `esim_compatibility` package.
typedef EsimCompatibilityChecker = Future<bool> Function();

/// Detects the current operating system for install / compatibility routing.
abstract class EsimHostPlatform {
  /// Creates a host-platform detector.
  const EsimHostPlatform();

  /// Default detector backed by `dart:io` / `kIsWeb`.
  factory EsimHostPlatform.current() = DefaultEsimHostPlatform;

  /// Whether the app is running on Android.
  bool get isAndroid;

  /// Whether the app is running on iOS.
  bool get isIOS;

  /// Stable platform name used in results and exceptions.
  String get name;
}

/// Production [EsimHostPlatform] implementation.
class DefaultEsimHostPlatform implements EsimHostPlatform {
  /// Creates the default host-platform detector.
  const DefaultEsimHostPlatform();

  @override
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  bool get isIOS => !kIsWeb && Platform.isIOS;

  @override
  String get name {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    if (Platform.isMacOS) {
      return 'macos';
    }
    if (Platform.isWindows) {
      return 'windows';
    }
    if (Platform.isLinux) {
      return 'linux';
    }
    if (Platform.isFuchsia) {
      return 'fuchsia';
    }
    return 'unknown';
  }
}

/// Installs eSIM profiles through platform Universal Link provisioning URLs.
///
/// Compatibility checks are delegated to
/// [`esim_compatibility`](https://pub.dev/packages/esim_compatibility).
///
/// ### Android
/// Provide an LPA activation string:
/// ```dart
/// await EsimUniversalInstaller().install(lpa: r'LPA:1$smdp.example.com$MATCH');
/// ```
///
/// Compatibility uses `EuiccManager.isEnabled()` via `esim_compatibility`.
///
/// ### iOS
/// Provide SM-DP+ address and matching ID (iOS 17.4+ Universal Link flow):
/// ```dart
/// await EsimUniversalInstaller().install(
///   smdp: 'smdp.example.com',
///   matchingId: 'MATCHING-ID',
/// );
/// ```
///
/// iOS compatibility uses `esim_compatibility`, which:
/// - detects the device model (`UIDevice`)
/// - compares against a list of known eSIM-supported Apple devices
///
/// **Important:** iOS results are **not confirmed** (`isConfirmed: false`).
/// Apple does not provide a reliable public third-party API equivalent to
/// Android's `EuiccManager.isEnabled()`.
class EsimUniversalInstaller {
  /// Creates an installer.
  ///
  /// [hostPlatform], [urlBuilder], [urlLauncher], and [compatibilityChecker]
  /// are injectable for tests.
  EsimUniversalInstaller({
    EsimHostPlatform? hostPlatform,
    EsimProvisioningUrlBuilder? urlBuilder,
    EsimUrlLauncher? urlLauncher,
    EsimCompatibilityChecker? compatibilityChecker,
  })  : _hostPlatform = hostPlatform ?? const DefaultEsimHostPlatform(),
        _urlBuilder = urlBuilder ?? const EsimProvisioningUrlBuilder(),
        _urlLauncher = urlLauncher ?? _defaultLaunchUrl,
        _compatibilityChecker =
            compatibilityChecker ?? EsimCompatibility.isEsimCompatible;

  final EsimHostPlatform _hostPlatform;
  final EsimProvisioningUrlBuilder _urlBuilder;
  final EsimUrlLauncher _urlLauncher;
  final EsimCompatibilityChecker _compatibilityChecker;

  /// Shared URL builder used for inspection and advanced callers.
  EsimProvisioningUrlBuilder get urlBuilder => _urlBuilder;

  static Future<bool> _defaultLaunchUrl(
    Uri url, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) {
    return launchUrl(url, mode: mode);
  }

  /// Checks whether the device appears to support eSIM.
  ///
  /// Uses [`esim_compatibility`](https://pub.dev/packages/esim_compatibility):
  /// - **Android:** `EuiccManager.isEnabled()` → [EsimSupportStatus.supported]
  ///   / [EsimSupportStatus.unsupported] (`isConfirmed: true`)
  /// - **iOS:** `UIDevice` model mapped to a known eSIM device list →
  ///   supported / unsupported (`isConfirmed: false`). **Not confirmed** by a
  ///   public Apple API.
  /// - **Other platforms:** [EsimSupportStatus.unsupported]
  ///
  /// This method does not throw for ordinary unsupported / unknown outcomes.
  Future<EsimCompatibilityResult> checkCompatibility() async {
    final platformName = _hostPlatform.name;

    if (!_hostPlatform.isAndroid && !_hostPlatform.isIOS) {
      return EsimCompatibilityResult(
        status: EsimSupportStatus.unsupported,
        platform: platformName,
        isConfirmed: false,
        details:
            'eSIM Universal Link installation is only supported on Android '
            'and iOS.',
      );
    }

    try {
      final compatible = await _compatibilityChecker();

      if (_hostPlatform.isIOS) {
        return EsimCompatibilityResult(
          status: compatible
              ? EsimSupportStatus.supported
              : EsimSupportStatus.unsupported,
          platform: 'ios',
          isConfirmed: false,
          details: compatible
              ? 'esim_compatibility reports this Apple device model as '
                  'eSIM-capable (UIDevice model compared against a known '
                  'eSIM-supported device list). This result is NOT confirmed '
                  'by a public Apple eSIM API.'
              : 'esim_compatibility reports this Apple device model as not '
                  'eSIM-capable (UIDevice model compared against a known '
                  'eSIM-supported device list). This result is NOT confirmed '
                  'by a public Apple eSIM API.',
        );
      }

      // Android
      return EsimCompatibilityResult(
        status: compatible
            ? EsimSupportStatus.supported
            : EsimSupportStatus.unsupported,
        platform: 'android',
        isConfirmed: true,
        details: compatible
            ? 'esim_compatibility reports EuiccManager embedded subscriptions '
                'are enabled.'
            : 'esim_compatibility reports EuiccManager is unavailable, '
                'disabled, or the device does not expose an enabled eUICC. '
                'Android 10+ alone does not guarantee eSIM hardware support.',
      );
    } catch (error) {
      return EsimCompatibilityResult(
        status: EsimSupportStatus.unknown,
        platform: platformName,
        isConfirmed: false,
        details: 'Unable to determine eSIM support via esim_compatibility: '
            '$error',
      );
    }
  }

  /// Convenience wrapper around [checkCompatibility].
  ///
  /// Returns `true` only when the status is [EsimSupportStatus.supported].
  ///
  /// On iOS, a `true` result still comes from the `esim_compatibility`
  /// device-model list and is **not confirmed** (`isConfirmed: false`).
  Future<bool> isEsimSupported() async {
    final result = await checkCompatibility();
    return result.isSupported;
  }

  /// Opens the platform eSIM provisioning Universal Link.
  ///
  /// Provide platform-appropriate activation data:
  /// - **iOS:** [smdp] and [matchingId]
  /// - **Android:** [lpa]
  ///
  /// Throws:
  /// - [EsimValidationException] for missing / invalid inputs
  /// - [EsimUnsupportedPlatformException] on web / desktop
  /// - [EsimLaunchException] when the URL cannot be opened
  Future<EsimInstallResult> install({
    String? smdp,
    String? matchingId,
    String? lpa,
  }) async {
    if (_hostPlatform.isIOS) {
      return _installIos(smdp: smdp, matchingId: matchingId);
    }
    if (_hostPlatform.isAndroid) {
      return _installAndroid(lpa: lpa);
    }

    throw EsimUnsupportedPlatformException(
      'eSIM Universal Link installation is only available on Android and iOS.',
      platform: _hostPlatform.name,
    );
  }

  /// Installs on iOS using SM-DP+ address and matching ID.
  Future<EsimInstallResult> installOnIos({
    required String smdp,
    required String matchingId,
  }) {
    if (!_hostPlatform.isIOS) {
      throw EsimUnsupportedPlatformException(
        'installOnIos() can only be called on iOS.',
        platform: _hostPlatform.name,
      );
    }
    return _installIos(smdp: smdp, matchingId: matchingId);
  }

  /// Installs on Android using a full LPA activation string.
  Future<EsimInstallResult> installOnAndroid({
    required String lpa,
  }) {
    if (!_hostPlatform.isAndroid) {
      throw EsimUnsupportedPlatformException(
        'installOnAndroid() can only be called on Android.',
        platform: _hostPlatform.name,
      );
    }
    return _installAndroid(lpa: lpa);
  }

  Future<EsimInstallResult> _installIos({
    String? smdp,
    String? matchingId,
  }) async {
    if (smdp == null || matchingId == null) {
      throw const EsimValidationException(
        'iOS eSIM installation requires both smdp and matchingId.',
      );
    }

    final url = _urlBuilder.buildIosUrl(smdp: smdp, matchingId: matchingId);
    await _launchProvisioningUrl(url);
    return EsimInstallResult(provisioningUrl: url, platform: 'ios');
  }

  Future<EsimInstallResult> _installAndroid({String? lpa}) async {
    if (lpa == null) {
      throw const EsimValidationException(
        'Android eSIM installation requires an lpa activation string.',
      );
    }

    final url = _urlBuilder.buildAndroidUrl(lpa: lpa);
    await _launchProvisioningUrl(url);
    return EsimInstallResult(provisioningUrl: url, platform: 'android');
  }

  Future<void> _launchProvisioningUrl(Uri url) async {
    try {
      final launched = await _urlLauncher(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw EsimLaunchException(
          'The eSIM provisioning URL could not be launched.',
          url: url,
        );
      }
    } on EsimLaunchException {
      rethrow;
    } catch (error) {
      throw EsimLaunchException(
        'Failed to open the eSIM provisioning URL.',
        url: url,
        cause: error,
      );
    }
  }
}
