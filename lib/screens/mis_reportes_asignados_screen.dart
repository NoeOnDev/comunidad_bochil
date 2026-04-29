import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../models/reporte.dart';
import '../providers/connectivity_provider.dart';
import '../providers/providers.dart';
import '../widgets/offline_state_widget.dart';

class MisReportesAsignadosScreen extends ConsumerWidget {
  const MisReportesAsignadosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conectividad = ref.watch(conectividadProvider).valueOrNull ?? true;
    final reportesAsync = ref.watch(misReportesAsignadosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis reportes asignados')),
      body: Column(
        children: [
          if (!conectividad) const OfflineBanner(),
          Expanded(
            child: reportesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => OfflineStateWidget(
                onReintentar: () =>
                    ref.invalidate(misReportesAsignadosProvider),
              ),
              data: (reportes) {
                if (reportes.isEmpty) {
                  return const _EstadoVacio();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(misReportesAsignadosProvider);
                    await ref.read(misReportesAsignadosProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: reportes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final reporte = reportes[index];
                      return _ReporteAsignadoCard(reporte: reporte);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.assignment_turned_in_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'Aún no tienes reportes asignados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Cuando administración te asigne un reporte, lo verás aquí para darle seguimiento.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReporteAsignadoCard extends StatelessWidget {
  const _ReporteAsignadoCard({required this.reporte});

  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/reporte-detalle', extra: reporte),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reporte.titulo,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _EstadoBadge(estado: reporte.estado),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                reporte.descripcion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(
                    icon: Icons.category_outlined,
                    texto: reporte.categoria.value,
                  ),
                  _MetaChip(icon: Icons.place_outlined, texto: reporte.colonia),
                  _MetaChip(
                    icon: Icons.person_outline,
                    texto: reporte.nombreAutor ?? 'Ciudadano',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatearFecha(reporte.updatedAt),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  const Text(
                    'Ver detalle',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$anio · $hora:$minuto';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado});

  final EstadoReporte estado;

  @override
  Widget build(BuildContext context) {
    final (color, fondo) = switch (estado) {
      EstadoReporte.pendiente => (
        const Color(0xFFB26A00),
        const Color(0xFFFFF3E0),
      ),
      EstadoReporte.enRevision => (
        const Color(0xFF1565C0),
        const Color(0xFFE3F2FD),
      ),
      EstadoReporte.enProgreso => (
        const Color(0xFF6A1B9A),
        const Color(0xFFF3E5F5),
      ),
      EstadoReporte.resuelto => (
        const Color(0xFF2E7D32),
        const Color(0xFFE8F5E9),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        estado.value,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
