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
import '../models/perfil_usuario.dart';
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
  bool _actualizandoEstado = false;
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
        final esRed =
            e is SocketException ||
            e.toString().contains('SocketException') ||
            e.toString().contains('Failed host lookup');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              esRed
                  ? 'Sin conexión. No se pudo registrar tu voto.'
                  : 'Error al votar: $e',
            ),
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

  bool _puedeGestionarOperativamente(PerfilUsuario? perfil) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (perfil == null || userId == null) return false;

    if (perfil.esAdmin || perfil.esCoordinador) {
      return true;
    }

    return perfil.esTecnico && reporte.asignadoA == userId;
  }

  Future<void> _cambiarEstadoOperativo(PerfilUsuario perfil) async {
    final resultado = await showDialog<_CambioEstadoResultado>(
      context: context,
      builder: (ctx) => _CambiarEstadoDialog(estadoActual: _estadoActual),
    );

    if (resultado == null || !mounted) return;

    setState(() => _actualizandoEstado = true);

    try {
      await ref
          .read(reportesRepositoryProvider)
          .actualizarEstadoOperativo(
            reporteId: reporte.id,
            estadoActual: _estadoActual,
            estadoNuevo: resultado.estadoNuevo,
            comentario: resultado.comentario,
          );

      setState(() {
        _estadoActual = resultado.estadoNuevo;
        _updatedAtActual = DateTime.now();
      });

      ref.invalidate(historialEstadosProvider(reporte.id));
      ref.invalidate(todosReportesProvider);
      ref.invalidate(reporteDetallePorIdProvider(reporte.id));
      ref.invalidate(misReportesAsignadosProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seguimiento actualizado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar el seguimiento: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _actualizandoEstado = false);
      }
    }
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
        await ref.read(reportesRepositoryProvider).eliminarReporte(reporte.id);
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
    final perfilAsync = ref.watch(perfilUsuarioProvider);

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
                    Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Sin evidencia fotográfica',
                      style: TextStyle(color: Colors.grey),
                    ),
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
                          horizontal: 12,
                          vertical: 6,
                        ),
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
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _colorEstado(
                            _estadoActual,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _iconEstado(_estadoActual),
                              size: 14,
                              color: _colorEstado(_estadoActual),
                            ),
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

                  perfilAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (perfil) {
                      if (!_puedeGestionarOperativamente(perfil)) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.14,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Seguimiento operativo',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Actualiza el avance del reporte y agrega una nota breve para dejar trazabilidad del trabajo realizado.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: _actualizandoEstado
                                      ? null
                                      : () => _cambiarEstadoOperativo(perfil!),
                                  icon: _actualizandoEstado
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.sync_alt),
                                  label: Text(
                                    _actualizandoEstado
                                        ? 'Actualizando seguimiento...'
                                        : 'Actualizar seguimiento',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),

                  // Botones de acción: Apoyar + Comentar
                  perfilAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (perfil) {
                      if (perfil?.esTecnico ?? false) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _toggleVoto,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _votado
                                          ? AppColors.primary.withValues(
                                              alpha: 0.1,
                                            )
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _votado
                                            ? AppColors.primary
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.comment_outlined,
                                          color: AppColors.textSecondary,
                                          size: 20,
                                        ),
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
                        ],
                      );
                    },
                  ),

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
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
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

class _CambioEstadoResultado {
  const _CambioEstadoResultado({
    required this.estadoNuevo,
    required this.comentario,
  });

  final EstadoReporte estadoNuevo;
  final String comentario;
}

class _CambiarEstadoDialog extends StatefulWidget {
  const _CambiarEstadoDialog({required this.estadoActual});

  final EstadoReporte estadoActual;

  @override
  State<_CambiarEstadoDialog> createState() => _CambiarEstadoDialogState();
}

class _CambiarEstadoDialogState extends State<_CambiarEstadoDialog> {
  late EstadoReporte _estadoSeleccionado;
  late final TextEditingController _comentarioController;

  @override
  void initState() {
    super.initState();
    _estadoSeleccionado = EstadoReporte.values.firstWhere(
      (estado) => estado != widget.estadoActual,
      orElse: () => widget.estadoActual,
    );
    _comentarioController = TextEditingController();
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Actualizar seguimiento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona el nuevo estado del reporte y agrega una nota si quieres dejar contexto del avance.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<EstadoReporte>(
              initialValue: _estadoSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Nuevo estado',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: EstadoReporte.values
                  .where((estado) => estado != widget.estadoActual)
                  .map(
                    (estado) => DropdownMenuItem(
                      value: estado,
                      child: Text(estado.value),
                    ),
                  )
                  .toList(),
              onChanged: (valor) {
                if (valor != null) {
                  setState(() => _estadoSeleccionado = valor);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _comentarioController,
              decoration: const InputDecoration(
                labelText: 'Comentario operativo (opcional)',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.edit_note_outlined),
                hintText:
                    'Ej: Se localizó la fuga y el equipo ya trabaja en la reparación.',
              ),
              minLines: 3,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              _CambioEstadoResultado(
                estadoNuevo: _estadoSeleccionado,
                comentario: _comentarioController.text.trim(),
              ),
            );
          },
          child: const Text('Guardar seguimiento'),
        ),
      ],
    );
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
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
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
