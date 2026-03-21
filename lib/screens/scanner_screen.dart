import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/constants.dart';
import '../providers/providers.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _procesando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_procesando) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final qrValue = barcode.rawValue!.trim();

    // Validar que sea un UUID v4
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!uuidRegex.hasMatch(qrValue)) return;

    setState(() => _procesando = true);
    await _controller.stop();

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final invitacion = await authRepo.validarInvitacion(qrValue);

      if (!mounted) return;

      if (invitacion == null) {
        _mostrarError('Código QR inválido o ya fue utilizado.');
        await _controller.start();
        setState(() => _procesando = false);
        return;
      }

      // Guardar la invitación en el estado global
      ref.read(invitacionEnProcesoProvider.notifier).state = invitacion;
      context.go('/contract-verify');
    } catch (e) {
      if (!mounted) return;
      _mostrarError('Error al validar el código. Verifica tu conexión.');
      await _controller.start();
      setState(() => _procesando = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear Invitación')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              color: AppColors.primary,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner,
                      color: Colors.white, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    _procesando
                        ? 'Verificando código...'
                        : 'Apunta la cámara al código QR\nde tu invitación de Comunidad Bochil',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
