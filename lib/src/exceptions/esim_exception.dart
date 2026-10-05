/// Base exception for all `esim_universal_installer` failures.
class EsimException implements Exception {
  /// Creates a package exception.
  const EsimException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// Optional underlying error.
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return 'EsimException: $message';
    }
    return 'EsimException: $message (cause: $cause)';
  }
}

/// Thrown when required install parameters are missing or invalid.
class EsimValidationException extends EsimException {
  /// Creates a validation exception.
  const EsimValidationException(super.message, {super.cause});

  @override
  String toString() => 'EsimValidationException: $message';
}

/// Thrown when the current platform cannot install eSIMs via this package.
class EsimUnsupportedPlatformException extends EsimException {
  /// Creates an unsupported-platform exception.
  const EsimUnsupportedPlatformException(
    super.message, {
    required this.platform,
    super.cause,
  });

  /// Platform that was detected (for example `web` or `windows`).
  final String platform;

  @override
  String toString() {
    return 'EsimUnsupportedPlatformException($platform): $message';
  }
}

/// Thrown when the provisioning URL could not be opened.
class EsimLaunchException extends EsimException {
  /// Creates a launch exception.
  const EsimLaunchException(
    super.message, {
    required this.url,
    super.cause,
  });

  /// URL that failed to launch.
  final Uri url;

  @override
  String toString() => 'EsimLaunchException: $message (url: $url)';
}

/// Thrown when a native platform-channel call fails unexpectedly.
class EsimPlatformException extends EsimException {
  /// Creates a platform-channel exception.
  const EsimPlatformException(
    super.message, {
    this.code,
    super.cause,
  });

  /// Optional platform error code.
  final String? code;

  @override
  String toString() {
    if (code == null) {
      return 'EsimPlatformException: $message';
    }
    return 'EsimPlatformException($code): $message';
  }
}
