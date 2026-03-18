import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../providers/providers.dart';

class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _enviando = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _enviarOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);

    // Formatear número con prefijo de México si no lo tiene
    String telefono = _phoneController.text.trim();
    if (!telefono.startsWith('+')) {
      telefono = '+52$telefono';
    }

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.enviarOtp(telefono);

      if (!mounted) return;

      // Guardar teléfono para la verificación
      ref.read(telefonoRegistroProvider.notifier).state = telefono;
      context.go('/otp-verify');
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
          content: Text('Error al enviar el SMS: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Número de Teléfono')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                const Icon(Icons.phone_android,
                    size: 64, color: AppColors.primary),
                const SizedBox(height: 24),
                const Text(
                  'Ingresa tu número celular',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Te enviaremos un código de verificación por SMS.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Número celular (10 dígitos)',
                    prefixIcon: Icon(Icons.phone),
                    prefixText: '+52 ',
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _enviarOtp(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Campo requerido';
                    final digits = v.trim().replaceAll(RegExp(r'[^\d]'), '');
                    if (digits.length != 10) return 'Ingresa 10 dígitos';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _enviando ? null : _enviarOtp,
                  child: _enviando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Enviar Código'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _enviando ? null : () => context.push('/recuperacion'),
                  child: const Text('¿No puedes recibir SMS? Recupera acceso por correo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
