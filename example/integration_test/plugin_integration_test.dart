import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:esim_universal_installer/esim_universal_installer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('compatibility check completes', (WidgetTester tester) async {
    final installer = EsimUniversalInstaller();
    final result = await installer.checkCompatibility();

    expect(result.platform, isNotEmpty);
    expect(result.status, isA<EsimSupportStatus>());
  });
}
