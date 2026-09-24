import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/NavigationTitle.dart';

class BarcodeScannerSimple extends StatefulWidget {
  const BarcodeScannerSimple({super.key, this.title});

  final String? title;

  @override
  State<BarcodeScannerSimple> createState() => _BarcodeScannerSimpleState();
}

class _BarcodeScannerSimpleState extends State<BarcodeScannerSimple> with WidgetsBindingObserver {
  Barcode? _barcode;
  bool _hasPopped = false;
  PermissionStatus? _cameraPermission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestCameraPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestCameraPermission(requestIfNeeded: false);
    }
  }

  Future<void> _requestCameraPermission({bool requestIfNeeded = true}) async {
    PermissionStatus status;
    try {
      status = await Permission.camera.status;
      if (requestIfNeeded && !status.isGranted) {
        status = await Permission.camera.request();
      }
    } catch (_) {
      status = PermissionStatus.denied;
    }
    if (mounted) setState(() => _cameraPermission = status);
  }

  Widget _buildBarcode(Barcode? value) {
    if (value == null) {
      return Text(
        widget.title ?? 'Scan QR Code',
        overflow: TextOverflow.fade,
        style: const TextStyle(color: Colors.white),
      );
    }

    return Text(
      value.displayValue ?? 'Invalid QR Code',
      overflow: TextOverflow.fade,
      style: const TextStyle(color: Colors.white),
    );
  }

  void _handleBarcode(BarcodeCapture barcodes) {
    if (_hasPopped || !mounted) return;
    if (barcodes.barcodes.isNotEmpty) {
      _hasPopped = true;
      Navigator.of(context).pop(barcodes.barcodes.first.rawValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Container(),
        title: NavigationTitle(title: widget.title ?? 'Scan QR Code'.toUpperCase()),
        centerTitle: true,
        backgroundColor: HomeTheme.darkTheme.colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            color: HomeTheme.darkTheme.colorScheme.onPrimary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: _buildScannerBody(),
    );
  }

  Widget _buildScannerBody() {
    final permission = _cameraPermission;
    if (permission == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (!permission.isGranted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Camera access is required to scan QR codes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeTheme.darkTheme.colorScheme.primary,
                  foregroundColor: HomeTheme.darkTheme.colorScheme.onPrimary,
                ),
                onPressed: permission.isPermanentlyDenied ? openAppSettings : _requestCameraPermission,
                child: Text(permission.isPermanentlyDenied ? 'Open Settings' : 'Allow Camera'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          onDetect: _handleBarcode,
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            alignment: Alignment.bottomCenter,
            height: 100,
            color: Colors.black.withValues(alpha: 0.4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(child: Center(child: _buildBarcode(_barcode))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
