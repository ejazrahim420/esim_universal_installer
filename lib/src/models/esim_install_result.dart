/// Result of a successful eSIM provisioning URL launch.
class EsimInstallResult {
  /// Creates an install result.
  const EsimInstallResult({
    required this.provisioningUrl,
    required this.platform,
    this.launched = true,
  });

  /// The Universal Link / provisioning URL that was opened.
  final Uri provisioningUrl;

  /// Platform on which installation was initiated (`android` or `ios`).
  final String platform;

  /// Whether [url_launcher] reported that the URL was launched.
  final bool launched;

  @override
  String toString() {
    return 'EsimInstallResult('
        'platform: $platform, '
        'launched: $launched, '
        'provisioningUrl: $provisioningUrl)';
  }

  @override
  bool operator ==(Object other) {
    return other is EsimInstallResult &&
        other.provisioningUrl == provisioningUrl &&
        other.platform == platform &&
        other.launched == launched;
  }

  @override
  int get hashCode => Object.hash(provisioningUrl, platform, launched);
}
