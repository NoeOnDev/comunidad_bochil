import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/cached_tile_layer.dart';
import '../providers/providers.dart';
import '../providers/connectivity_provider.dart';
import '../models/reporte.dart';
import '../services/local_database_service.dart';
import '../widgets/offline_state_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MapController _mapController = MapController();
  List<ReportePendiente> _pendientes = [];

  @override
  void initState() {
    super.initState();
    _cargarPendientes();
  }

  Future<void> _cargarPendientes() async {
    final lista = await LocalDatabaseService.obtenerPendientes();
    if (mounted) setState(() => _pendientes = lista);
  }

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
    final conectado = ref.watch(conectividadProvider).valueOrNull ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comunidad Bochil'),
      ),
      body: Column(
        children: [
          if (!conectado) const OfflineBanner(),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: bochilCenter,
                initialZoom: 14.0,
              ),
              children: [
                CachedTileLayerBuilder.build(),
                reportesAsync.when(
                  data: (reportes) => MarkerLayer(
                    markers: [
                      ..._pendientes.map(_buildPendienteMarker),
                      ...reportes.map(_buildMarker),
                    ],
                  ),
                  loading: () => MarkerLayer(
                    markers: _pendientes.map(_buildPendienteMarker).toList(),
                  ),
                  error: (_, _) => MarkerLayer(
                    markers: _pendientes.map(_buildPendienteMarker).toList(),
                  ),
                ),
              ],
            ),
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

  Marker _buildPendienteMarker(ReportePendiente p) {
    return Marker(
      point: LatLng(p.latitud, p.longitud),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _mostrarDetallePendiente(p),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.orange.shade400,
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
          child: const Icon(Icons.schedule, color: Colors.white, size: 20),
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
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconoPorCategoria(reporte.categoria),
                  color: _colorPorCategoria(reporte.categoria),
                ),
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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            if (reporte.fotosUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: reporte.fotosUrls.first,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    height: 120,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Colonia: ${reporte.colonia.isNotEmpty ? reporte.colonia : 'Colonia no especificada'}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/reporte-detalle', extra: reporte);
                },
                child: const Text('Ver detalle completo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDetallePendiente(ReportePendiente p) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 14,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pendiente de env\u00edo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              p.descripcion,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            if (p.listaFotos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: p.listaFotos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final archivo = File(p.listaFotos[i]);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: archivo.existsSync()
                          ? Image.file(
                              archivo,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image),
                            ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Colonia: ${p.colonia}',
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
