import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:esim_universal_installer/esim_universal_installer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EsimInstallerExampleApp());
}

class EsimInstallerExampleApp extends StatelessWidget {
  const EsimInstallerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eSIM Universal Installer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const EsimInstallerHomePage(),
    );
  }
}

class EsimInstallerHomePage extends StatefulWidget {
  const EsimInstallerHomePage({super.key});

  @override
  State<EsimInstallerHomePage> createState() => _EsimInstallerHomePageState();
}

class _EsimInstallerHomePageState extends State<EsimInstallerHomePage> {
  final _installer = EsimUniversalInstaller();

  // Sample placeholders only — never use real production activation codes here.
  final _smdpController = TextEditingController(text: 'smdp.example.com');
  final _matchingIdController = TextEditingController(
    text: 'SAMPLE-MATCHING-ID',
  );
  final _lpaController = TextEditingController(
    text: r'LPA:1$smdp.example.com$SAMPLE-MATCHING-ID',
  );

  EsimCompatibilityResult? _compatibility;
  String? _statusMessage;
  bool _statusIsError = false;
  bool _busy = false;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  bool get _isIOS => !kIsWeb && Platform.isIOS;

  String get _platformLabel {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isAndroid) {
      return 'Android';
    }
    if (Platform.isIOS) {
      return 'iOS';
    }
    return Platform.operatingSystem;
  }

  @override
  void initState() {
    super.initState();
    _refreshCompatibility();
  }

  @override
  void dispose() {
    _smdpController.dispose();
    _matchingIdController.dispose();
    _lpaController.dispose();
    super.dispose();
  }

  Future<void> _refreshCompatibility() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    try {
      final result = await _installer.checkCompatibility();
      if (!mounted) {
        return;
      }
      setState(() {
        _compatibility = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusIsError = true;
        _statusMessage = 'Compatibility check failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    try {
      final EsimInstallResult result;
      if (_isIOS) {
        result = await _installer.install(
          smdp: _smdpController.text,
          matchingId: _matchingIdController.text,
        );
      } else if (_isAndroid) {
        result = await _installer.install(lpa: _lpaController.text);
      } else {
        throw const EsimUnsupportedPlatformException(
          'This example only installs eSIMs on Android and iOS devices.',
          platform: 'unsupported',
        );
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _statusIsError = false;
        _statusMessage =
            'Opened provisioning URL on ${result.platform}:\n${result.provisioningUrl}';
      });
    } on EsimException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusIsError = true;
        _statusMessage = error.toString();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusIsError = true;
        _statusMessage = 'Unexpected error: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compatibility = _compatibility;

    return Scaffold(
      appBar: AppBar(title: const Text('eSIM Universal Installer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Platform: $_platformLabel',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _isIOS
                ? 'iOS Universal Link installation requires iOS 17.4+.'
                : _isAndroid
                ? 'Android installation targets API 29+ devices with an enabled eUICC.'
                : 'Installation is only available on Android and iOS.',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compatibility',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (compatibility == null)
                    const Text('Checking…')
                  else ...[
                    Text('Status: ${compatibility.status.name}'),
                    Text('Platform: ${compatibility.platform}'),
                    Text(
                      'Confirmed: ${compatibility.isConfirmed ? 'yes' : 'no'}',
                    ),
                    if (!compatibility.isConfirmed) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'iOS compatibility comes from esim_compatibility '
                        '(UIDevice model list) and is NOT confirmed by a '
                        'public Apple eSIM API.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                    if (compatibility.details != null) ...[
                      const SizedBox(height: 8),
                      Text(compatibility.details!),
                    ],
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _busy ? null : _refreshCompatibility,
                    child: const Text('Refresh compatibility'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isIOS) ...[
            TextField(
              controller: _smdpController,
              decoration: const InputDecoration(
                labelText: 'SM-DP+ address',
                border: OutlineInputBorder(),
                helperText: 'Sample value for demonstration only',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _matchingIdController,
              decoration: const InputDecoration(
                labelText: 'Matching ID',
                border: OutlineInputBorder(),
                helperText: 'Sample value for demonstration only',
              ),
            ),
          ] else if (_isAndroid) ...[
            TextField(
              controller: _lpaController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'LPA activation string',
                border: OutlineInputBorder(),
                helperText: 'Sample value for demonstration only',
              ),
            ),
          ] else ...[
            const Text(
              'Run this example on an Android or iOS device/simulator to try '
              'installation.',
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy || (!_isAndroid && !_isIOS) ? null : _install,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sim_card_download_outlined),
            label: const Text('Install eSIM'),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _statusMessage!,
              style: TextStyle(
                color: _statusIsError
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Notes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            '• Sample SM-DP+ / Matching ID / LPA values above are placeholders.\n'
            '• Opening the provisioning URL starts the system eSIM flow; it does '
            'not guarantee a successful profile download.\n'
            '• Compatibility uses the esim_compatibility package.\n'
            '• On iOS, esim_compatibility detects the UIDevice model and compares '
            'it to a known eSIM-supported Apple device list. That result is '
            'NOT confirmed by a public Apple eSIM API (isConfirmed: false).',
          ),
        ],
      ),
    );
  }
}
