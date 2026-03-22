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
    // Fuerza rebuild de esta pantalla cuando cambia el estado de auth
    // (por ejemplo al volver desde email_change / magic link).
    ref.watch(authStateProvider);
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
    final authUserAsync = ref.watch(authUserServerProvider);
    final authUser =
        authUserAsync.valueOrNull ?? ref.watch(supabaseClientProvider).auth.currentUser;
    final nombre = perfil?.nombreCompleto ?? 'Usuario';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';
    final telefono =
        perfil?.telefono ??
        authUser?.phone ??
        'Sin teléfono';
    final email =
      authUser?.email ??
      perfil?.email ??
      'Sin correo vinculado';
    final tieneCorreoVinculado = (authUser?.email ?? '').trim().isNotEmpty;
    final correoConfirmado = authUser?.emailConfirmedAt != null;
    final correoPendienteConfirmacion =
        tieneCorreoVinculado && !correoConfirmado;
    final correoActual = (authUser?.email ?? '').trim();
    final colonia = perfil?.colonia ?? 'Sin colonia';
    final calle = perfil?.calle ?? 'Sin calle';
    final contrato = perfil?.numeroContrato;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
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
                  icon: Icons.alternate_email,
                  title: 'Correo',
                  subtitle: email,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 56, right: 16, bottom: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: !tieneCorreoVinculado
                            ? Colors.orange.withValues(alpha: 0.12)
                            : (correoConfirmado
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.amber.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        !tieneCorreoVinculado
                            ? 'Sin correo para recuperación'
                            : (correoConfirmado
                                ? 'Correo vinculado y confirmado'
                                : 'Correo vinculado, pendiente de confirmación'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: !tieneCorreoVinculado
                              ? Colors.orange.shade800
                              : (correoConfirmado
                                  ? Colors.green.shade700
                                  : Colors.amber.shade900),
                        ),
                      ),
                    ),
                  ),
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

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: correoPendienteConfirmacion
                    ? null
                    : () => _vincularCorreo(context, ref),
                icon: const Icon(Icons.mark_email_read_outlined),
                label: Text(
                  correoPendienteConfirmacion
                      ? 'Confirmación de correo pendiente'
                      : (tieneCorreoVinculado
                      ? 'Actualizar Correo de Recuperación'
                      : 'Vincular Correo para Recuperación'),
                ),
              ),
            ),
          ),
          if (correoPendienteConfirmacion)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                'Revisa tu bandeja y confirma el correo antes de actualizarlo o usar recuperación por email.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (correoActual.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                'Al actualizar el correo, por seguridad debes confirmar el enlace en el correo actual y en el nuevo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 12),

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
          const SizedBox(height: 20),
        ],
      ),
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

  Future<void> _vincularCorreo(BuildContext context, WidgetRef ref) async {
    String emailInput = '';
    try {
      final email = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Vincular correo'),
          content: TextField(
            keyboardType: TextInputType.emailAddress,
            onChanged: (value) => emailInput = value,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'usuario@correo.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, emailInput.trim().toLowerCase()),
              child: const Text('Vincular'),
            ),
          ],
        ),
      );

      if (email == null || email.isEmpty || !context.mounted) return;

      final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      if (!regex.hasMatch(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Correo no válido.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final authUserResponse = await ref.read(supabaseClientProvider).auth.getUser();
      final authUser = authUserResponse.user;
      final correoActual = (authUser?.email ?? '').trim().toLowerCase();
      final correoConfirmado = authUser?.emailConfirmedAt != null;
      final tieneCorreoPrevio = correoActual.isNotEmpty;

      if (!context.mounted) return;

      if (correoActual.isNotEmpty && correoActual == email) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              correoConfirmado
                  ? 'Ese correo ya está vinculado y confirmado.'
                  : 'Ese correo ya está vinculado. Revisa tu bandeja para confirmar el enlace pendiente.',
            ),
            backgroundColor: correoConfirmado ? Colors.blueGrey : Colors.orange,
          ),
        );
        return;
      }

      if (tieneCorreoPrevio) {
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmar actualización de correo'),
            content: const Text(
              'Por seguridad recibirás un enlace en tu correo actual y otro en el nuevo. Debes confirmar ambos para completar el cambio.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );

        if (confirmar != true || !context.mounted) return;
      }

      await ref.read(authRepositoryProvider).vincularCorreo(email);
      ref.invalidate(authUserServerProvider);
      ref.invalidate(perfilUsuarioProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tieneCorreoPrevio
                ? 'Solicitud enviada. Revisa tu correo actual y el nuevo para confirmar ambos enlaces.'
                : 'Correo vinculado. Revisa tu bandeja para confirmar el enlace de verificación.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo vincular el correo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
