import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import 'reporte_detalle_screen.dart';

class ReporteDetalleLoaderScreen extends ConsumerWidget {
  final String reporteId;

  const ReporteDetalleLoaderScreen({
    super.key,
    required this.reporteId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reporteAsync = ref.watch(reporteDetallePorIdProvider(reporteId));

    return reporteAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _ErrorDetalleScreen(
        mensaje: 'No se pudo abrir el reporte.',
      ),
      data: (reporte) {
        if (reporte == null) {
          return _ErrorDetalleScreen(
            mensaje: 'Reporte no encontrado o sin acceso.',
          );
        }
        return ReporteDetalleScreen(reporte: reporte);
      },
    );
  }
}

class _ErrorDetalleScreen extends StatelessWidget {
  final String mensaje;

  const _ErrorDetalleScreen({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Reporte')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.report_problem_outlined, size: 56),
              const SizedBox(height: 12),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Volver a Comunidad'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
