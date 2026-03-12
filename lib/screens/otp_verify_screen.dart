import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../providers/providers.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _verificando = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verificarOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _verificando = true);

    final telefono = ref.read(telefonoRegistroProvider);
    final codigo = _otpController.text.trim();

    try {
      final authRepo = ref.read(authRepositoryProvider);

      // Verificar OTP
      await authRepo.verificarOtp(telefono: telefono, codigo: codigo);

      if (!mounted) return;

      // Solo consolidar registro si viene del flujo de QR (registro nuevo).
      // Si invitacion es null, es un login normal → no insertar perfil.
      final invitacion = ref.read(invitacionEnProcesoProvider);
      if (invitacion != null) {
        final qrMarcado = await authRepo.consolidarRegistro(
          invitacion: invitacion,
          telefono: telefono,
        );

        // Limpiar estado temporal
        ref.read(invitacionEnProcesoProvider.notifier).state = null;
        ref.read(telefonoRegistroProvider.notifier).state = '';

        if (!mounted) return;

        if (!qrMarcado) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Registro exitoso. Pendiente: aplicar fix de políticas en Supabase.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
          context.go('/');
          return;
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Registro exitoso! Bienvenido a SAPAM Bochil.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Login normal (usuario existente)
        ref.read(telefonoRegistroProvider.notifier).state = '';

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Bienvenido de vuelta!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      context.go('/');
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error Supabase: ${e.message}'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al verificar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final telefono = ref.watch(telefonoRegistroProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verificar Código')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                const Icon(Icons.sms, size: 64, color: AppColors.primary),
                const SizedBox(height: 24),
                const Text(
                  'Ingresa el código de verificación',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enviamos un SMS al número $telefono',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: 'Código de 6 dígitos',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLength: 6,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _verificarOtp(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Campo requerido';
                    if (v.trim().length != 6) return 'Ingresa los 6 dígitos';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _verificando ? null : _verificarOtp,
                  child: _verificando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Verificar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
