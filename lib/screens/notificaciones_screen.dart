import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../models/notificacion_app.dart';
import '../providers/providers.dart';

enum FiltroNotificaciones { todas, noLeidas }

class NotificacionesScreen extends ConsumerStatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  ConsumerState<NotificacionesScreen> createState() =>
      _NotificacionesScreenState();
}

class _NotificacionesScreenState extends ConsumerState<NotificacionesScreen> {
  FiltroNotificaciones _filtro = FiltroNotificaciones.todas;

  String _tiempoRelativo(DateTime fecha) {
    final d = DateTime.now().difference(fecha);
    if (d.inMinutes < 1) return 'Ahora';
    if (d.inMinutes < 60) return 'Hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'Hace ${d.inHours} h';
    if (d.inDays < 7) return 'Hace ${d.inDays} días';
    return 'Hace ${(d.inDays / 7).floor()} sem';
  }

  IconData _icono(TipoNotificacionApp tipo) {
    switch (tipo) {
      case TipoNotificacionApp.alertaOficial:
        return Icons.campaign_outlined;
      case TipoNotificacionApp.estadoReporte:
        return Icons.update_outlined;
    }
  }

  Color _color(TipoNotificacionApp tipo) {
    switch (tipo) {
      case TipoNotificacionApp.alertaOficial:
        return Colors.orange;
      case TipoNotificacionApp.estadoReporte:
        return AppColors.primary;
    }
  }

  Future<void> _abrirNotificacion(NotificacionApp n) async {
    await ref.read(notificacionesRepositoryProvider).marcarLeida(n);
    ref.invalidate(notificacionesProvider);

    if (!mounted) return;
    if (n.reporteId != null && n.reporteId!.isNotEmpty) {
      context.push('/reporte-detalle-id/${n.reporteId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificacionesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            tooltip: 'Marcar todas como leídas',
            onPressed: () async {
              final lista = ref.read(notificacionesProvider).valueOrNull ?? [];
              await ref
                  .read(notificacionesRepositoryProvider)
                  .marcarTodasLeidas(lista);
              ref.invalidate(notificacionesProvider);
            },
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _filtro == FiltroNotificaciones.todas,
                  onSelected: (_) =>
                      setState(() => _filtro = FiltroNotificaciones.todas),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('No leídas'),
                  selected: _filtro == FiltroNotificaciones.noLeidas,
                  onSelected: (_) =>
                      setState(() => _filtro = FiltroNotificaciones.noLeidas),
                ),
              ],
            ),
          ),
          Expanded(
            child: notifsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: Text('No se pudieron cargar las notificaciones.'),
              ),
              data: (notifs) {
                final lista = _filtro == FiltroNotificaciones.noLeidas
                    ? notifs.where((n) => !n.leida).toList()
                    : notifs;

                if (lista.isEmpty) {
                  return const Center(
                    child: Text(
                      'No tienes notificaciones.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: lista.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (_, index) {
                    final n = lista[index];
                    final color = _color(n.tipo);
                    return ListTile(
                      onTap: () => _abrirNotificacion(n),
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.12),
                        child: Icon(_icono(n.tipo), color: color),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.titulo,
                              style: TextStyle(
                                fontWeight:
                                    n.leida ? FontWeight.w500 : FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!n.leida)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(n.mensaje),
                          const SizedBox(height: 4),
                          Text(
                            _tiempoRelativo(n.fecha),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
