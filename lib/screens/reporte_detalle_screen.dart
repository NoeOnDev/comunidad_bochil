import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import '../core/constants.dart';
import '../models/reporte.dart';

class ReporteDetalleScreen extends StatelessWidget {
  final Reporte reporte;

  const ReporteDetalleScreen({super.key, required this.reporte});

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
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Reporte')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Galería de fotos
            if (reporte.fotosUrls.isNotEmpty)
              _FotoCarrusel(fotos: reporte.fotosUrls)
            else
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey.shade200,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Sin evidencia fotográfica',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categoría + Estatus
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          reporte.categoria.value,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _colorEstado(reporte.estado)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_iconEstado(reporte.estado),
                                size: 14,
                                color: _colorEstado(reporte.estado)),
                            const SizedBox(width: 4),
                            Text(
                              reporte.estado.value,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _colorEstado(reporte.estado),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Título
                  Text(
                    reporte.titulo,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Descripción
                  const Text(
                    'Descripción',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reporte.descripcion,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Info Cards
                  _InfoTile(
                    icon: Icons.location_on,
                    label: 'Colonia',
                    value: reporte.colonia,
                  ),
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.calendar_today,
                    label: 'Fecha de creación',
                    value: _formatearFecha(reporte.createdAt),
                  ),
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.thumb_up_alt_outlined,
                    label: 'Votos de apoyo',
                    value: reporte.votosApoyo.toString(),
                  ),
                  const SizedBox(height: 20),

                  // Mini mapa
                  if (reporte.ubicacion.latitude != 0.0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ubicación',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 180,
                            child: AbsorbPointer(
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: reporte.ubicacion,
                                  initialZoom: 16,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: reporte.ubicacion,
                                        width: 40,
                                        height: 40,
                                        child: const Icon(
                                          Icons.location_on,
                                          color: AppColors.error,
                                          size: 40,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatearFecha(DateTime dt) {
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${dt.day} de ${meses[dt.month - 1]} de ${dt.year}';
  }
}

class _FotoCarrusel extends StatefulWidget {
  final List<String> fotos;
  const _FotoCarrusel({required this.fotos});

  @override
  State<_FotoCarrusel> createState() => _FotoCarruselState();
}

class _FotoCarruselState extends State<_FotoCarrusel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.fotos.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, index) {
              return GestureDetector(
                onTap: () => _mostrarFotoCompleta(context, widget.fotos[index]),
                child: CachedNetworkImage(
                  imageUrl: widget.fotos[index],
                  width: double.infinity,
                  height: 260,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, _, _) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, size: 48),
                  ),
                ),
              );
            },
          ),
        ),
        // Indicadores de página
        if (widget.fotos.length > 1)
          Positioned(
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  widget.fotos.length,
                  (i) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == i
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _mostrarFotoCompleta(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
