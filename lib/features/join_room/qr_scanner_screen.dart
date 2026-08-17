import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// Pantalla de cámara para escanear el QR del lobby. Devuelve el texto
/// crudo leído (Navigator.pop) para que quien la abrió lo interprete
/// como código de conexión.
///
/// A propósito **no** usa `KenaColors`: el fondo es siempre la vista de
/// cámara (negro), sea cual sea el tema activo de la app — como
/// cualquier pantalla de cámara, en cualquier app. Un color "ajustado
/// por tema" acá sería el bug real: en un tema claro, `KenaColors.text2`
/// resuelve a un gris oscuro pensado para fondo blanco, invisible sobre
/// la vista de cámara.
class _QrScannerColors {
  _QrScannerColors._();
  static const accent = Color(0xFF2ECDA8);
  static const text2 = Color(0x8CFFFFFF);
  static const red = Color(0xFFFF6B6B);
}

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _handled = false;
  // `null` mientras se resuelve el pedido de permiso — se comprueba acá
  // (no se confía sólo en `MobileScanner.errorBuilder`) para poder
  // mostrar un estado propio, del sistema de diseño, en vez de que la
  // cámara se quede en un cuadro negro sin ninguna explicación si el
  // permiso ya estaba denegado (el bug reportado: "el código QR está
  // roto" — en la mayoría de los casos era justo esto).
  PermissionStatus? _cameraStatus;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraStatus = status);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final status = _cameraStatus;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear código QR'),
      ),
      body: status == null
          ? const Center(child: CircularProgressIndicator(color: _QrScannerColors.accent))
          : status.isGranted
              ? _buildScanner()
              : _PermissionDeniedState(permanentlyDenied: status.isPermanentlyDenied, onRetry: _checkPermission),
    );
  }

  Widget _buildScanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          onDetect: _onDetect,
          errorBuilder: (context, error) => _ScannerErrorState(error: error),
        ),
        Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              children: [
                _corner(top: 0, left: 0, sides: const [true, true, false, false]),
                _corner(top: 0, right: 0, sides: const [true, false, false, true]),
                _corner(bottom: 0, left: 0, sides: const [false, true, true, false]),
                _corner(bottom: 0, right: 0, sides: const [false, false, true, true]),
                Positioned(
                  left: 6,
                  right: 6,
                  top: 99,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: _QrScannerColors.accent,
                      boxShadow: [BoxShadow(color: _QrScannerColors.accent.withValues(alpha: 0.7), blurRadius: 8)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          bottom: 48,
          left: 32,
          right: 32,
          child: Text(
            'Apuntá al código QR que te compartieron',
            textAlign: TextAlign.center,
            style: TextStyle(color: _QrScannerColors.text2, fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  /// [sides] = [top, left, bottom, right] — cuáles bordes dibujar en esta esquina.
  Widget _corner({double? top, double? left, double? bottom, double? right, required List<bool> sides}) {
    const side = BorderSide(color: _QrScannerColors.accent, width: 3);
    return Positioned(
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border(
            top: sides[0] ? side : BorderSide.none,
            left: sides[1] ? side : BorderSide.none,
            bottom: sides[2] ? side : BorderSide.none,
            right: sides[3] ? side : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _PermissionDeniedState extends StatelessWidget {
  const _PermissionDeniedState({required this.permanentlyDenied, required this.onRetry});

  final bool permanentlyDenied;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_rounded, size: 40, color: _QrScannerColors.text2),
            const SizedBox(height: 16),
            const Text(
              'Kena necesita permiso de cámara para escanear un código QR.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: permanentlyDenied ? openAppSettings : onRetry,
              child: Text(permanentlyDenied ? 'Abrir Ajustes' : 'Dar permiso'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerErrorState extends StatelessWidget {
  const _ScannerErrorState({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: _QrScannerColors.red),
            const SizedBox(height: 16),
            const Text(
              'No pudimos abrir la cámara.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Probá ingresar el código a mano.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _QrScannerColors.text2, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
