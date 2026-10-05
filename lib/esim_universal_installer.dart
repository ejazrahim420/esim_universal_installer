/// Install eSIMs via Apple and Android Universal Link provisioning URLs.
///
/// Installation opens the platform eSIM setup flow using official provisioning
/// URLs. Compatibility checks are provided by
/// [`esim_compatibility`](https://pub.dev/packages/esim_compatibility).
library;

export 'src/esim_universal_installer.dart';
export 'src/exceptions/esim_exception.dart';
export 'src/models/esim_compatibility_result.dart';
export 'src/models/esim_install_result.dart';
export 'src/models/esim_support_status.dart';
export 'src/provisioning_url_builder.dart';
