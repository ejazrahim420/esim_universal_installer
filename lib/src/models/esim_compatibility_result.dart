import 'esim_support_status.dart';

/// Result of an eSIM compatibility check.
class EsimCompatibilityResult {
  /// Creates a compatibility result.
  const EsimCompatibilityResult({
    required this.status,
    required this.platform,
    this.details,
    this.isConfirmed = true,
  });

  /// High-level support status.
  final EsimSupportStatus status;

  /// Platform identifier, such as `android`, `ios`, `web`, or `windows`.
  final String platform;

  /// Human-readable explanation of the result.
  final String? details;

  /// Whether this result comes from a confirmed system API check.
  ///
  /// - **Android:** `true` — based on `EuiccManager.isEnabled()`
  /// - **iOS:** `false` — based on a device-model list only (not confirmed by
  ///   a public Apple eSIM API)
  final bool isConfirmed;

  /// Whether [status] is [EsimSupportStatus.supported].
  bool get isSupported => status == EsimSupportStatus.supported;

  /// Whether [status] is [EsimSupportStatus.unknown].
  bool get isUnknown => status == EsimSupportStatus.unknown;

  @override
  String toString() {
    final buffer = StringBuffer(
      'EsimCompatibilityResult('
      'status: $status, '
      'platform: $platform, '
      'isConfirmed: $isConfirmed',
    );
    if (details != null) {
      buffer.write(', details: $details');
    }
    buffer.write(')');
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    return other is EsimCompatibilityResult &&
        other.status == status &&
        other.platform == platform &&
        other.details == details &&
        other.isConfirmed == isConfirmed;
  }

  @override
  int get hashCode => Object.hash(status, platform, details, isConfirmed);
}
