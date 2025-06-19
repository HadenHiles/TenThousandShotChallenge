import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/NavigationTitle.dart';

class BarcodeScannerSimple extends StatefulWidget {
  const BarcodeScannerSimple({super.key, this.title});

  final String? title;

  @override
  State<BarcodeScannerSimple> createState() => _BarcodeScannerSimpleState();
}

class _BarcodeScannerSimpleState extends State<BarcodeScannerSimple> {
  Barcode? _barcode;

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
    if (barcodes.barcodes.isNotEmpty) {
      return Navigator.of(context).pop(barcodes.barcodes.first.rawValue);
    } else {
      return Navigator.of(context).pop();
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
      body: Stack(
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
      ),
    );
  }
}
