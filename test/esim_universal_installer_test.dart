import 'package:flutter_test/flutter_test.dart';
import 'package:esim_universal_installer/esim_universal_installer.dart';
import 'package:url_launcher/url_launcher.dart';

class _FakeHostPlatform implements EsimHostPlatform {
  const _FakeHostPlatform({
    required this.isAndroid,
    required this.isIOS,
    required this.name,
  });

  @override
  final bool isAndroid;

  @override
  final bool isIOS;

  @override
  final String name;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EsimProvisioningUrlBuilder', () {
    const builder = EsimProvisioningUrlBuilder();

    test('builds iOS Universal Link with unencoded LPA separators', () {
      final url = builder.buildIosUrl(
        smdp: 'smdp.example.com',
        matchingId: 'MATCH-123',
      );

      expect(
        url.toString(),
        'https://esimsetup.apple.com/esim_qrcode_provisioning'
        '?carddata=LPA:1\$smdp.example.com\$MATCH-123',
      );
      expect(
        url.queryParameters['carddata'],
        r'LPA:1$smdp.example.com$MATCH-123',
      );
      expect(url.query, contains(r'LPA:1$smdp.example.com$MATCH-123'));
      expect(url.toString(), isNot(contains('%24')));
    });

    test('trims iOS inputs', () {
      final url = builder.buildIosUrl(
        smdp: '  smdp.example.com  ',
        matchingId: '  MATCH  ',
      );

      expect(url.query, contains(r'LPA:1$smdp.example.com$MATCH'));
    });

    test('rejects empty iOS smdp', () {
      expect(
        () => builder.buildIosUrl(smdp: ' ', matchingId: 'MATCH'),
        throwsA(isA<EsimValidationException>()),
      );
    });

    test('rejects empty iOS matchingId', () {
      expect(
        () => builder.buildIosUrl(smdp: 'smdp.example.com', matchingId: ''),
        throwsA(isA<EsimValidationException>()),
      );
    });

    test('rejects iOS values containing LPA separators', () {
      expect(
        () => builder.buildIosUrl(
          smdp: r'bad$smdp',
          matchingId: 'MATCH',
        ),
        throwsA(isA<EsimValidationException>()),
      );
    });

    test('builds Android provisioning URL from LPA', () {
      const lpa = r'LPA:1$smdp.example.com$MATCH-123';
      final url = builder.buildAndroidUrl(lpa: lpa);

      expect(
        url.toString(),
        'https://esimsetup.android.com/esim_qrcode_provisioning?carddata=$lpa',
      );
    });

    test('rejects empty Android LPA', () {
      expect(
        () => builder.buildAndroidUrl(lpa: '   '),
        throwsA(isA<EsimValidationException>()),
      );
    });
  });

  group('EsimUniversalInstaller.install', () {
    test('installs on iOS with smdp and matchingId', () async {
      Uri? launchedUrl;
      LaunchMode? launchedMode;

      final installer = EsimUniversalInstaller(
        hostPlatform: const _FakeHostPlatform(
          isAndroid: false,
          isIOS: true,
          name: 'ios',
        ),
        urlLauncher: (url, {mode = LaunchMode.platformDefault}) async {
          launchedUrl = url;
          launchedMode = mode;
          return true;
        },
      );

      final result = await installer.install(
        smdp: 'smdp.example.com',
        matchingId: 'MATCH-123',
      );

      expect(result.platform, 'ios');
      expect(result.launched, isTrue);
      expect(
        result.provisioningUrl.toString(),
        contains('esimsetup.apple.com'),
      );
      expect(launchedUrl, result.provisioningUrl);
      expect(launchedMode, LaunchMode.externalApplication);
    });

    test('installs on Android with LPA', () async {
      final installer = EsimUniversalInstaller(
        hostPlatform: const _FakeHostPlatform(
          isAndroid: true,
          isIOS: false,
          name: 'android',
        ),
        urlLauncher: (url, {mode = LaunchMode.platformDefault}) async => true,
      );

      final result = await installer.install(
        lpa: r'LPA:1$smdp.example.com$MATCH-123',
      );

      expect(result.platform, 'android');
      expect(
        result.provisioningUrl.toString(),
        contains('esimsetup.android.com'),
      );
    });

    test('validates missing iOS parameters', () async {
      final installer = EsimUniversalInstaller(
        hostPlatform: const _FakeHostPlatform(
          isAndroid: false,
          isIOS: true,
          name: 'ios',
        ),
        urlLauncher: (url, {mode = LaunchMode.platformDefault}) async => true,
      );

      expect(
        () => installer.install(lpa: r'LPA:1$x$y'),
        throwsA(isA<EsimValidationException>()),
      );
    });

    test('validates missing Android LPA', () async {
      final installer = EsimUniversalInstaller(
        hostPlatform: const _FakeHostPlatform(
          isAndroid: true,
          isIOS: false,
          name: 'android',
        ),
        urlLauncher: (url, {mode = LaunchMode.platformDefault}) async => true,
      );

      expect(
        () => installer.install(smdp: 'smdp.example.com', matchingId: 'MATCH'),
        throwsA(isA<EsimValidationException>()),
      );
    });

    test('rejects unsupported platforms', () async {
      final installer = EsimUniversalInstaller(
        hostPlatform: const _FakeHostPlatform(
          isAndroid: false,
          isIOS: false,
          name: 'web',
        ),
        urlLauncher: (url, {mode = LaunchMode.platformDefault}) async => true,
      );

      expect(
        () => installer.install(lpa: r'LPA:1$x$y'),
        throwsA(
          isA<EsimUnsupportedPlatformException>().having(
            (error) => error.platform,
            'platform',
            'web',
          ),
        ),
      );
    });

    test('throws when URL launch fails', () async {
      final installer = EsimUniversalInstaller(
        hostPlatform: const _FakeHostPlatform(
          isAndroid: true,
          isIOS: false,
          name: 'android',
        ),
        urlLauncher: (url, {mode = LaunchMode.platformDefault}) async => false,
      );

      expect(
        () => installer.install(lpa: r'LPA:1$smdp.example.com$MATCH'),
        throwsA(isA<EsimLaunchException>()),
      );
    });

    test('wraps unexpected launch errors', () async {
      final installer = EsimUniversalInstaller(
        hostPlatform: const _FakeHostPlatform(
          isAndroid: false,
          isIOS: true,
          name: 'ios',
        ),
        urlLauncher: (url, {mode = LaunchMode.platformDefault}) async {
          throw Exception('boom');
        },
      );

      expect(
        () => installer.install(smdp: 'smdp.example.com', matchingId: 'MATCH'),
        throwsA(
          isA<EsimLaunchException>().having(
            (error) => error.cause,
            'cause',
            isA<Exception>(),
          ),
        ),
      );
    });

    test('installOnIos rejects non-iOS hosts', () async {
      final installer = EsimUniversalInstaller(
        hostPlatform: const _FakeHostPlatform(
          isAndroid: true,
          isIOS: false,
          name: 'android',
        ),
        urlLauncher: (url, {mode = LaunchMode.platformDefault}) async => true,
      );

      expect(
        () => installer.installOnIos(smdp: 'smdp.example.com', matchingId: 'M'),
        throwsA(isA<EsimUnsupportedPlatformException>()),
      );
    });

    test('installOnAndroid rejects non-Android hosts', () async {
      final installer = EsimUniversalInstaller(
        hostPlatform: const _FakeHostPlatform(
          isAndroid: false,
          isIOS: true,
          name: 'ios',
        ),
        urlLauncher: (url, {mode = LaunchMode.platformDefault}) async => true,
      );

      expect(
        () => installer.installOnAndroid(lpa: r'LPA:1$x$y'),
        throwsA(isA<EsimUnsupportedPlatformException>()),
      );
    });
  });

  group('EsimUniversalInstaller.checkCompatibility', () {
    test('returns unsupported on web/desktop without calling checker',
        () async {
      var called = false;
      final installer = EsimUniversalInstaller(
        hostPlatform: const _FakeHostPlatform(
          isAndroid: false,
          isIOS: false,
          name: 'macos',
        ),
        compatibilityChecker: () async {
          called = true;
          return true;
        },
      );

      final result = await installer.checkCompatibility();

      expect(called, isFalse);
      expect(result.status, EsimSupportStatus.unsupported);
      expect(result.platform, 'macos');
      expect(result.isConfirmed, isFalse);
    });

    test('maps Android esim_compatibility true to supported', () async {
      final installer = EsimUniversalInstaller(
        hostPlatform: const _FakeHostPlatform(
          isAndroid: true,
          isIOS: false,
          name: 'android',
        ),
        compatibilityChecker: () async => true,
      );

      final result = await installer.checkCompatibility();

      expect(result.status, EsimSupportStatus.supported);
      expect(result.platform, 'android');
      expect(result.isConfirmed, isTrue);
      expect(result.details, contains('EuiccManager'));
      expect(await installer.isEsimSupported(), isTrue);
    });

    test('maps Android esim_compatibility false to unsupported', () async {
      final installer = EsimUniversalInstaller(
        hostPlatform: const _FakeHostPlatform(
          isAndroid: true,
          isIOS: false,
          name: 'android',
        ),
        compatibilityChecker: () async => false,
      );

      final result = await installer.checkCompatibility();

      expect(result.status, EsimSupportStatus.unsupported);
      expect(result.isConfirmed, isTrue);
      expect(await installer.isEsimSupported(), isFalse);
    });

    test('maps iOS esim_compatibility true to unconfirmed supported', () async {
      final installer = EsimUniversalInstaller(
        hostPlatform: const _FakeHostPlatform(
          isAndroid: false,
          isIOS: true,
          name: 'ios',
        ),
        compatibilityChecker: () async => true,
      );

      final result = await installer.checkCompatibility();

      expect(result.status, EsimSupportStatus.supported);
      expect(result.platform, 'ios');
      expect(result.isConfirmed, isFalse);
      expect(result.details, contains('UIDevice'));
      expect(result.details, contains('NOT confirmed'));
      expect(await installer.isEsimSupported(), isTrue);
    });

    test('maps iOS esim_compatibility false to unconfirmed unsupported',
        () async {
      final installer = EsimUniversalInstaller(
        hostPlatform: const _FakeHostPlatform(
          isAndroid: false,
          isIOS: true,
          name: 'ios',
        ),
        compatibilityChecker: () async => false,
      );

      final result = await installer.checkCompatibility();

      expect(result.status, EsimSupportStatus.unsupported);
      expect(result.isConfirmed, isFalse);
      expect(result.details, contains('NOT confirmed'));
      expect(await installer.isEsimSupported(), isFalse);
    });

    test('returns unknown when esim_compatibility throws', () async {
      final installer = EsimUniversalInstaller(
        hostPlatform: const _FakeHostPlatform(
          isAndroid: true,
          isIOS: false,
          name: 'android',
        ),
        compatibilityChecker: () async => throw Exception('native failure'),
      );

      final result = await installer.checkCompatibility();

      expect(result.status, EsimSupportStatus.unknown);
      expect(result.details, contains('Unable to determine'));
    });
  });

  group('result models', () {
    test('compatibility result equality', () {
      const a = EsimCompatibilityResult(
        status: EsimSupportStatus.supported,
        platform: 'ios',
        isConfirmed: false,
      );
      const b = EsimCompatibilityResult(
        status: EsimSupportStatus.supported,
        platform: 'ios',
        isConfirmed: false,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('isConfirmed: false'));
    });

    test('install result equality', () {
      final url = Uri.parse('https://example.com');
      final a = EsimInstallResult(provisioningUrl: url, platform: 'ios');
      final b = EsimInstallResult(provisioningUrl: url, platform: 'ios');

      expect(a, equals(b));
      expect(a.toString(), contains('ios'));
    });
  });
}
