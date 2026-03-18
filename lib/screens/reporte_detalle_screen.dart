import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/cached_tile_layer.dart';
import '../models/reporte.dart';
import '../providers/providers.dart';
import '../widgets/comentarios_bottom_sheet.dart';
import '../widgets/timeline_estados_widget.dart';

class ReporteDetalleScreen extends ConsumerStatefulWidget {
  final Reporte reporte;

  const ReporteDetalleScreen({super.key, required this.reporte});

  @override
  ConsumerState<ReporteDetalleScreen> createState() =>
      _ReporteDetalleScreenState();
}

class _ReporteDetalleScreenState extends ConsumerState<ReporteDetalleScreen> {
  late bool _votado;
  late int _conteoVotos;
  late EstadoReporte _estadoActual;
  late DateTime _updatedAtActual;
  StreamSubscription<List<Map<String, dynamic>>>? _votosSub;
  StreamSubscription<List<Map<String, dynamic>>>? _historialSub;
  StreamSubscription<List<Map<String, dynamic>>>? _reporteSub;
  Timer? _votosDebounce;
  Timer? _historialDebounce;
  Timer? _reporteDebounce;

  Reporte get reporte => widget.reporte;

  @override
  void initState() {
    super.initState();
    // Inicializar desde datos enriquecidos del feed
    _votado = reporte.usuarioHaVotado;
    _conteoVotos = reporte.conteoVotos;
    _estadoActual = reporte.estado;
    _updatedAtActual = reporte.updatedAt;
    // Verificar datos frescos en background
    _cargarVotos();
    _iniciarRealtime();
  }

  @override
  void dispose() {
    _votosSub?.cancel();
    _historialSub?.cancel();
    _reporteSub?.cancel();
    _votosDebounce?.cancel();
    _historialDebounce?.cancel();
    _reporteDebounce?.cancel();
    super.dispose();
  }

  void _programarRefrescoVotos() {
    _votosDebounce?.cancel();
    _votosDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _cargarVotos();
      ref.invalidate(todosReportesProvider);
    });
  }

  void _programarRefrescoHistorial() {
    _historialDebounce?.cancel();
    _historialDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      ref.invalidate(historialEstadosProvider(reporte.id));
    });
  }

  void _programarRefrescoReporte(Map<String, dynamic> row) {
    _reporteDebounce?.cancel();
    _reporteDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;

      final estadoRaw = (row['estado'] as String?)?.trim();
      final updatedAtRaw = row['updated_at'] as String?;

      final nuevoEstado = EstadoReporte.values.firstWhere(
        (e) => e.value == estadoRaw,
        orElse: () => _estadoActual,
      );
      final nuevoUpdatedAt = updatedAtRaw != null
          ? DateTime.tryParse(updatedAtRaw) ?? _updatedAtActual
          : _updatedAtActual;

      final cambioEstado = nuevoEstado != _estadoActual;
      final cambioTiempo = nuevoUpdatedAt != _updatedAtActual;
      if (cambioEstado || cambioTiempo) {
        setState(() {
          _estadoActual = nuevoEstado;
          _updatedAtActual = nuevoUpdatedAt;
        });
      }

      ref.invalidate(todosReportesProvider);
      ref.invalidate(reporteDetallePorIdProvider(reporte.id));
    });
  }

  void _iniciarRealtime() {
    final client = ref.read(supabaseClientProvider);

    _votosSub = client
        .from('votos_reportes')
        .stream(primaryKey: ['reporte_id', 'usuario_id'])
        .eq('reporte_id', reporte.id)
        .listen((_) {
          if (!mounted) return;
          _programarRefrescoVotos();
        });

    _historialSub = client
        .from('historial_estados')
        .stream(primaryKey: ['id'])
        .eq('reporte_id', reporte.id)
        .order('created_at', ascending: true)
        .listen((_) {
          if (!mounted) return;
          _programarRefrescoHistorial();
        });

    _reporteSub = client
        .from('reportes')
        .stream(primaryKey: ['id'])
        .eq('id', reporte.id)
        .listen((rows) {
          if (!mounted || rows.isEmpty) return;
          _programarRefrescoReporte(rows.first);
        });
  }

  Future<void> _cargarVotos() async {
    final repo = ref.read(reportesRepositoryProvider);
    final yaVoto = await repo.yaVoto(reporte.id);
    final conteo = await repo.contarVotos(reporte.id);
    if (mounted) {
      setState(() {
        _votado = yaVoto;
        _conteoVotos = conteo;
      });
    }
  }

  Future<void> _toggleVoto() async {
    // Actualización optimista
    setState(() {
      _votado = !_votado;
      _conteoVotos += _votado ? 1 : -1;
    });
    try {
      await ref.read(reportesRepositoryProvider).toggleVoto(reporte.id);
      // Sincronizar con el feed al votar
      ref.invalidate(todosReportesProvider);
    } catch (e) {
      // Revertir en caso de error
      setState(() {
        _votado = !_votado;
        _conteoVotos += _votado ? 1 : -1;
      });
      if (mounted) {
        final esRed = e is SocketException ||
            e.toString().contains('SocketException') ||
            e.toString().contains('Failed host lookup');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(esRed
                ? 'Sin conexión. No se pudo registrar tu voto.'
                : 'Error al votar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  bool get _puedeEliminar {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return reporte.usuarioId == userId &&
      _estadoActual == EstadoReporte.pendiente;
  }

  Future<void> _confirmarEliminacion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar reporte'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este reporte? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        await ref
            .read(reportesRepositoryProvider)
            .eliminarReporte(reporte.id);
        ref.invalidate(reportesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reporte eliminado correctamente.'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
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
      appBar: AppBar(
        title: const Text('Detalle del Reporte'),
        actions: [
          if (_puedeEliminar)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Eliminar reporte',
              onPressed: _confirmarEliminacion,
            ),
        ],
      ),
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
                          color: _colorEstado(_estadoActual)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_iconEstado(_estadoActual),
                                size: 14,
                                color: _colorEstado(_estadoActual)),
                            const SizedBox(width: 4),
                            Text(
                              _estadoActual.value,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _colorEstado(_estadoActual),
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
                    value: reporte.colonia.isNotEmpty
                        ? reporte.colonia
                        : 'Colonia no especificada',
                  ),
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.calendar_today,
                    label: 'Fecha de creación',
                    value: _formatearFecha(reporte.createdAt),
                  ),
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.hourglass_bottom,
                    label: _estadoActual == EstadoReporte.resuelto
                        ? 'Tiempo de resolución'
                        : 'Tiempo transcurrido',
                    value: _formatearDuracion(
                      _estadoActual == EstadoReporte.resuelto
                          ? _updatedAtActual.difference(reporte.createdAt)
                          : DateTime.now().difference(reporte.createdAt),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Seguimiento y SLA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Objetivo de servicio sugerido: 72 horas',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TimelineEstadosWidget(
                    reporteId: reporte.id,
                    fechaCreacion: reporte.createdAt,
                    estadoActual: _estadoActual,
                  ),
                  const SizedBox(height: 16),

                  // Botones de acción: Apoyar + Comentar
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _toggleVoto,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _votado
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _votado
                                    ? AppColors.primary
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _votado
                                      ? Icons.thumb_up_alt
                                      : Icons.thumb_up_off_alt,
                                  color: _votado
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Apoyar ($_conteoVotos)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _votado
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              mostrarComentarios(context, reporte.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.comment_outlined,
                                    color: AppColors.textSecondary,
                                    size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Comentar',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
                                  CachedTileLayerBuilder.build(),
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

  String _formatearDuracion(Duration duracion) {
    if (duracion.inDays >= 1) {
      final horas = duracion.inHours % 24;
      return '${duracion.inDays}d ${horas}h';
    }
    if (duracion.inHours >= 1) {
      final minutos = duracion.inMinutes % 60;
      return '${duracion.inHours}h ${minutos}m';
    }
    return '${duracion.inMinutes}m';
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
