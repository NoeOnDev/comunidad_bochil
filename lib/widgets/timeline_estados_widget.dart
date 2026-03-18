import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/historial_estado.dart';
import '../providers/providers.dart';

class TimelineEstadosWidget extends ConsumerWidget {
  final String reporteId;
  final DateTime fechaCreacion;
  final EstadoReporte estadoActual;

  const TimelineEstadosWidget({
    super.key,
    required this.reporteId,
    required this.fechaCreacion,
    required this.estadoActual,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historialAsync = ref.watch(historialEstadosProvider(reporteId));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: historialAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(8),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => _buildFallbackTimeline(),
        data: (historial) => _buildTimeline(historial),
      ),
    );
  }

  Widget _buildFallbackTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seguimiento',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _TimelineItem(
          titulo: 'Reporte creado',
          subtitulo: _tiempoRelativo(fechaCreacion),
          color: AppColors.primary,
          ultimo: false,
        ),
        _TimelineItem(
          titulo: 'Estado actual: ${estadoActual.value}',
          subtitulo: 'Sin historial de cambios disponible',
          color: _colorEstado(estadoActual),
          ultimo: true,
        ),
      ],
    );
  }

  Widget _buildTimeline(List<HistorialEstado> historial) {
    final items = <_TimelineData>[
      _TimelineData(
        titulo: 'Reporte creado',
        subtitulo: _tiempoRelativo(fechaCreacion),
        color: AppColors.primary,
      ),
      ...historial.map(
        (h) => _TimelineData(
          titulo: 'Cambio de estado a ${h.estadoNuevo.value}',
          subtitulo: h.comentario?.trim().isNotEmpty == true
              ? '${_tiempoRelativo(h.createdAt)} · ${h.comentario!.trim()}'
              : _tiempoRelativo(h.createdAt),
          color: _colorEstado(h.estadoNuevo),
        ),
      ),
    ];

    if (historial.isEmpty || historial.last.estadoNuevo != estadoActual) {
      items.add(
        _TimelineData(
          titulo: 'Estado actual: ${estadoActual.value}',
          subtitulo: _tiempoRelativo(DateTime.now()),
          color: _colorEstado(estadoActual),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seguimiento',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...List.generate(items.length, (index) {
          final item = items[index];
          return _TimelineItem(
            titulo: item.titulo,
            subtitulo: item.subtitulo,
            color: item.color,
            ultimo: index == items.length - 1,
          );
        }),
      ],
    );
  }

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

  String _tiempoRelativo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Hace unos segundos';
    if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} días';
  }
}

class _TimelineData {
  final String titulo;
  final String subtitulo;
  final Color color;

  _TimelineData({
    required this.titulo,
    required this.subtitulo,
    required this.color,
  });
}

class _TimelineItem extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Color color;
  final bool ultimo;

  const _TimelineItem({
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.ultimo,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                if (!ultimo)
                  Expanded(
                    child: Container(width: 2, color: Colors.grey.shade300),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
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
