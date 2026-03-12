import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../providers/providers.dart';
import '../models/reporte.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MapController _mapController = MapController();

  Color _colorPorCategoria(CategoriaReporte cat) {
    switch (cat) {
      case CategoriaReporte.fuga:
        return Colors.blue;
      case CategoriaReporte.sinAgua:
        return Colors.orange;
      case CategoriaReporte.bajaPresion:
        return Colors.yellow.shade700;
      case CategoriaReporte.contaminacion:
        return Colors.red;
      case CategoriaReporte.infraestructura:
        return Colors.grey;
    }
  }

  IconData _iconoPorCategoria(CategoriaReporte cat) {
    switch (cat) {
      case CategoriaReporte.fuga:
        return Icons.water_drop;
      case CategoriaReporte.sinAgua:
        return Icons.water_drop_outlined;
      case CategoriaReporte.bajaPresion:
        return Icons.speed;
      case CategoriaReporte.contaminacion:
        return Icons.warning;
      case CategoriaReporte.infraestructura:
        return Icons.build;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportesAsync = ref.watch(reportesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SAPAM Bochil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(reportesProvider),
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: bochilCenter,
          initialZoom: 14.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.sapam.comunidad_bochil',
          ),
          reportesAsync.when(
            data: (reportes) => MarkerLayer(
              markers: reportes.map((r) => _buildMarker(r)).toList(),
            ),
            loading: () => const MarkerLayer(markers: []),
            error: (_, _) => const MarkerLayer(markers: []),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/location-picker'),
        icon: const Icon(Icons.report_problem),
        label: const Text('Reportar Problema'),
      ),
    );
  }

  Marker _buildMarker(Reporte reporte) {
    return Marker(
      point: reporte.ubicacion,
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _mostrarDetalleReporte(reporte),
        child: Container(
          decoration: BoxDecoration(
            color: _colorPorCategoria(reporte.categoria),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _iconoPorCategoria(reporte.categoria),
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleReporte(Reporte reporte) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconoPorCategoria(reporte.categoria),
                    color: _colorPorCategoria(reporte.categoria)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reporte.titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Chip(label: Text(reporte.estado.value)),
            const SizedBox(height: 8),
            Text(
              reporte.descripcion,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Colonia: ${reporte.colonia}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
