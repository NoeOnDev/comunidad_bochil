import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../providers/providers.dart';

class ContractVerifyScreen extends ConsumerStatefulWidget {
  const ContractVerifyScreen({super.key});

  @override
  ConsumerState<ContractVerifyScreen> createState() =>
      _ContractVerifyScreenState();
}

class _ContractVerifyScreenState extends ConsumerState<ContractVerifyScreen> {
  final _contratoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _intentos = 0;
  static const _maxIntentos = 3;

  @override
  void dispose() {
    _contratoController.dispose();
    super.dispose();
  }

  void _verificar() {
    if (!_formKey.currentState!.validate()) return;

    final invitacion = ref.read(invitacionEnProcesoProvider);
    if (invitacion == null) {
      context.go('/scanner');
      return;
    }

    final contratoIngresado = _contratoController.text.trim();

    if (contratoIngresado == invitacion.numeroContrato) {
      context.go('/phone-input');
    } else {
      _intentos++;
      if (_intentos >= _maxIntentos) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demasiados intentos. Escanea el código nuevamente.'),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(invitacionEnProcesoProvider.notifier).state = null;
        context.go('/scanner');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Número de contrato incorrecto. Intentos restantes: ${_maxIntentos - _intentos}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificación de Seguridad')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                const Icon(Icons.verified_user,
                    size: 64, color: AppColors.primary),
                const SizedBox(height: 24),
                const Text(
                  'Ingresa tu número de contrato',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Este dato aparece en tu recibo de agua. '
                  'Lo necesitamos para verificar tu identidad.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _contratoController,
                  decoration: const InputDecoration(
                    labelText: 'Número de Contrato',
                    prefixIcon: Icon(Icons.assignment),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _verificar(),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _verificar,
                  child: const Text('Verificar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
