import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo / Icono
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.water_drop,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Comunidad Bochil',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aplicación comunitaria\npara reportes y participación ciudadana',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),

              const Spacer(flex: 2),

              // Botón primario: Iniciar Sesión
              ElevatedButton.icon(
                onPressed: () => context.push('/phone-input'),
                icon: const Icon(Icons.login),
                label: const Text('Iniciar Sesión'),
              ),
              const SizedBox(height: 16),

              // Botón secundario: Registro con QR
              TextButton.icon(
                onPressed: () => context.push('/scanner'),
                icon: const Icon(Icons.qr_code, color: AppColors.primary),
                label: const Text(
                  'Crear cuenta con Código QR',
                  style: TextStyle(color: AppColors.primary, fontSize: 15),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
