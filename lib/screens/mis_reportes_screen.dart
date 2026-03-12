import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../providers/providers.dart';
import '../models/reporte.dart';

/// Provider filtrado: solo los reportes del usuario autenticado.
final misReportesProvider = FutureProvider<List<Reporte>>((ref) async {
  final todos = await ref.watch(reportesRepositoryProvider).obtenerReportes();
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return [];
  return todos.where((r) => r.usuarioId == userId).toList();
});

class MisReportesScreen extends ConsumerWidget {
  const MisReportesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final misReportes = ref.watch(misReportesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(misReportesProvider),
          ),
        ],
      ),
      body: misReportes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error al cargar reportes: $e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (reportes) {
          if (reportes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Aún no has enviado reportes',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reportes.length,
            itemBuilder: (context, index) {
              final r = reportes[index];
              return _ReporteCard(reporte: r);
            },
          );
        },
      ),
    );
  }
}

class _ReporteCard extends StatelessWidget {
  final Reporte reporte;
  const _ReporteCard({required this.reporte});

  Color _colorEstado(EstadoReporte estado) {
    switch (estado) {
      case EstadoReporte.pendiente:
        return Colors.orange;
      case EstadoReporte.enRevision:
        return Colors.blue;
      case EstadoReporte.enProgreso:
        return AppColors.accent;
      case EstadoReporte.resuelto:
        return Colors.green;
    }
  }

  IconData _iconEstado(EstadoReporte estado) {
    switch (estado) {
      case EstadoReporte.pendiente:
        return Icons.schedule;
      case EstadoReporte.enRevision:
        return Icons.visibility;
      case EstadoReporte.enProgreso:
        return Icons.engineering;
      case EstadoReporte.resuelto:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/reporte-detalle', extra: reporte),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail (leading)
              _buildThumbnail(),
              const SizedBox(width: 14),

              // Contenido central
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reporte.titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reporte.categoria.value,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${reporte.colonia.isNotEmpty ? reporte.colonia : 'Colonia no especificada'} · ${_formatearFecha(reporte.createdAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Badge de estatus (trailing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _colorEstado(reporte.estado).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconEstado(reporte.estado),
                      size: 14,
                      color: _colorEstado(reporte.estado),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      reporte.estado.value,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _colorEstado(reporte.estado),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (reporte.fotosUrls.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: reporte.fotosUrls.first,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            width: 64,
            height: 64,
            color: Colors.grey.shade200,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (_, _, _) => _defaultThumbnail(),
        ),
      );
    }
    return _defaultThumbnail();
  }

  Widget _defaultThumbnail() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.water_drop,
        color: AppColors.primary,
        size: 28,
      ),
    );
  }

  String _formatearFecha(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
