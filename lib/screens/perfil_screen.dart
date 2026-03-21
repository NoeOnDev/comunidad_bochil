import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../models/perfil_usuario.dart';
import '../providers/providers.dart';
import '../widgets/offline_state_widget.dart';
import '../providers/connectivity_provider.dart';

class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(perfilUsuarioProvider);
    final conectado = ref.watch(conectividadProvider).valueOrNull ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: Column(
        children: [
          if (!conectado) const OfflineBanner(),
          Expanded(
            child: perfilAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => OfflineStateWidget(
                onReintentar: () => ref.invalidate(perfilUsuarioProvider),
              ),
              data: (perfil) => _PerfilContent(perfil: perfil),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerfilContent extends ConsumerWidget {
  final PerfilUsuario? perfil;
  const _PerfilContent({required this.perfil});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre = perfil?.nombreCompleto ?? 'Usuario';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';
    final telefono =
        perfil?.telefono ??
        ref.watch(supabaseClientProvider).auth.currentUser?.phone ??
        'Sin teléfono';
    final colonia = perfil?.colonia ?? 'Sin colonia';
    final calle = perfil?.calle ?? 'Sin calle';
    final contrato = perfil?.numeroContrato;

    return Column(
      children: [
        const SizedBox(height: 32),

        // Avatar con inicial
        CircleAvatar(
          radius: 52,
          backgroundColor: AppColors.primary,
          child: Text(
            inicial,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Nombre
        Text(
          nombre,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Ciudadano',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Tarjeta de información
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            color: Colors.white,
            child: Column(
              children: [
                _InfoListTile(
                  icon: Icons.phone,
                  title: 'Teléfono',
                  subtitle: telefono,
                ),
                const Divider(height: 1, indent: 56),
                _InfoListTile(
                  icon: Icons.location_on,
                  title: 'Colonia',
                  subtitle: colonia,
                ),
                const Divider(height: 1, indent: 56),
                _InfoListTile(
                  icon: Icons.route,
                  title: 'Calle',
                  subtitle: calle,
                ),
                if (contrato != null) ...[
                  const Divider(height: 1, indent: 56),
                  _InfoListTile(
                    icon: Icons.receipt_long,
                    title: 'Contrato',
                    subtitle: contrato,
                  ),
                ],
              ],
            ),
          ),
        ),

        const Spacer(),

        // Botón cerrar sesión
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _cerrarSesion(context, ref),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _cerrarSesion(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Estás seguro de que deseas salir de la aplicación?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      await ref.read(authRepositoryProvider).cerrarSesion();
      if (context.mounted) context.go('/welcome');
    }
  }
}

class _InfoListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
