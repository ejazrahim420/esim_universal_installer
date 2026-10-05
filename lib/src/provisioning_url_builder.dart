import 'exceptions/esim_exception.dart';

/// Builds official eSIM Universal Link / provisioning URLs.
///
/// These helpers are pure and side-effect free so callers (and tests) can
/// inspect the exact URL that will be opened.
class EsimProvisioningUrlBuilder {
  /// Apple eSIM Universal Link host path used on iOS 17.4+.
  static const String iosProvisioningBaseUrl =
      'https://esimsetup.apple.com/esim_qrcode_provisioning';

  /// Android eSIM provisioning host path.
  static const String androidProvisioningBaseUrl =
      'https://esimsetup.android.com/esim_qrcode_provisioning';

  /// Minimum Android API level supported by this package for install/check.
  static const int minAndroidApiLevel = 29;

  /// Minimum iOS version that supports Universal Link eSIM provisioning.
  static const String minIosVersion = '17.4';

  const EsimProvisioningUrlBuilder();

  /// Builds an iOS provisioning URL from an SM-DP+ address and matching ID.
  ///
  /// Format:
  /// `https://esimsetup.apple.com/esim_qrcode_provisioning?carddata=LPA:1$SMDP$MATCHING_ID`
  ///
  /// Throws [EsimValidationException] when either value is empty.
  Uri buildIosUrl({
    required String smdp,
    required String matchingId,
  }) {
    final normalizedSmdp = smdp.trim();
    final normalizedMatchingId = matchingId.trim();

    if (normalizedSmdp.isEmpty) {
      throw const EsimValidationException(
        'SM-DP+ address (smdp) is required for iOS eSIM installation.',
      );
    }
    if (normalizedMatchingId.isEmpty) {
      throw const EsimValidationException(
        'Matching ID is required for iOS eSIM installation.',
      );
    }
    _ensureNoLpaSeparator(normalizedSmdp, fieldName: 'smdp');
    _ensureNoLpaSeparator(normalizedMatchingId, fieldName: 'matchingId');

    // Keep `$` unencoded to match Apple's documented Universal Link examples.
    final carddata = 'LPA:1\$$normalizedSmdp\$$normalizedMatchingId';
    return Uri.parse('$iosProvisioningBaseUrl?carddata=$carddata');
  }

  /// Builds an Android provisioning URL from a full LPA activation string.
  ///
  /// Format:
  /// `https://esimsetup.android.com/esim_qrcode_provisioning?carddata=<LPA>`
  ///
  /// Throws [EsimValidationException] when [lpa] is empty.
  Uri buildAndroidUrl({required String lpa}) {
    final normalizedLpa = lpa.trim();
    if (normalizedLpa.isEmpty) {
      throw const EsimValidationException(
        'LPA activation string is required for Android eSIM installation.',
      );
    }

    return Uri.parse('$androidProvisioningBaseUrl?carddata=$normalizedLpa');
  }

  void _ensureNoLpaSeparator(String value, {required String fieldName}) {
    if (value.contains(r'$')) {
      throw EsimValidationException(
        'Invalid $fieldName: values must not contain the LPA separator "\$".',
      );
    }
  }
}
