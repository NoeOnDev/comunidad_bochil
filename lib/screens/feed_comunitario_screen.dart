import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/reporte.dart';
import '../providers/providers.dart';
import '../widgets/comentarios_bottom_sheet.dart';
import '../widgets/filtros_reportes_sheet.dart';
import '../widgets/offline_state_widget.dart';
import '../widgets/report_image_grid.dart';
import '../providers/connectivity_provider.dart';
import '../services/local_database_service.dart';

class FeedComunitarioScreen extends ConsumerStatefulWidget {
  const FeedComunitarioScreen({super.key});

  @override
  ConsumerState<FeedComunitarioScreen> createState() =>
      _FeedComunitarioScreenState();
}

class _FeedComunitarioScreenState extends ConsumerState<FeedComunitarioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<ReportePendiente> _pendientes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarPendientes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarPendientes() async {
    final lista = await LocalDatabaseService.obtenerPendientes();
    if (mounted) setState(() => _pendientes = lista);
  }

  void _invalidarDatos() {
    ref.invalidate(todosReportesProvider);
    ref.invalidate(alertasProvider);
    _cargarPendientes();
  }

  Future<void> _abrirFiltros() async {
    final actuales = ref.read(filtrosReportesProvider);
    final reportes = ref.read(todosReportesProvider).valueOrNull ?? [];
    final colonias = reportes
        .map((r) => r.colonia.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final seleccion = await mostrarFiltrosReportesSheet(
      context: context,
      inicial: actuales,
      coloniasDisponibles: colonias,
    );

    if (seleccion != null) {
      ref.read(filtrosReportesProvider.notifier).state = seleccion;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportesAsync = ref.watch(reportesFiltradosProvider);
    final alertasAsync = ref.watch(alertasProvider);
    final filtros = ref.watch(filtrosReportesProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final conectado = ref.watch(conectividadProvider).valueOrNull ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comunidad'),
        actions: [
          IconButton(
            tooltip: 'Filtrar',
            onPressed: _abrirFiltros,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune),
                if (filtros.tieneFiltrosActivos)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _invalidarDatos,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Todos los reportes'),
            Tab(text: 'Mis reportes'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!conectado) const OfflineBanner(),
          Expanded(
            child: reportesAsync.when(
              loading: () => const _ShimmerFeed(),
              error: (e, _) =>
                  OfflineStateWidget(onReintentar: _invalidarDatos),
              data: (todosReportes) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 0: Todos los reportes (públicos)
                    _TabContent(
                      reportes: todosReportes
                          .where((r) => r.esPublico)
                          .toList(),
                      alertas: alertasAsync,
                      onRefresh: _invalidarDatos,
                      emptyIcon: Icons.forum_outlined,
                      emptyMessage: 'Aún no hay reportes comunitarios',
                    ),
                    // Tab 1: Mis Reportes (con pendientes locales)
                    _TabContent(
                      reportes: todosReportes
                          .where((r) => r.usuarioId == userId)
                          .toList(),
                      reportesPendientes: _pendientes,
                      alertas: null,
                      onRefresh: _invalidarDatos,
                      emptyIcon: Icons.list_alt_outlined,
                      emptyMessage: 'No has creado ningún reporte',
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB CONTENT (Lista con alertas + reportes)
// ─────────────────────────────────────────────────────────────────────────────

class _TabContent extends ConsumerWidget {
  final List<Reporte> reportes;
  final List<ReportePendiente> reportesPendientes;
  final AsyncValue<List<Map<String, dynamic>>>? alertas;
  final VoidCallback onRefresh;
  final IconData emptyIcon;
  final String emptyMessage;

  const _TabContent({
    required this.reportes,
    this.reportesPendientes = const [],
    required this.alertas,
    required this.onRefresh,
    required this.emptyIcon,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalItems = reportesPendientes.length + reportes.length;
    final tieneAlertas = alertas != null;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: (totalItems == 0)
          ? ListView(
              children: [
                if (tieneAlertas) _AlertasBanner(alertas: alertas!),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(emptyIcon, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          emptyMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: totalItems + (tieneAlertas ? 1 : 0),
              itemBuilder: (context, index) {
                // Banner de alertas como primer item
                if (tieneAlertas && index == 0) {
                  return _AlertasBanner(alertas: alertas!);
                }
                final realIndex = tieneAlertas ? index - 1 : index;

                // Primero: reportes pendientes (locales)
                if (realIndex < reportesPendientes.length) {
                  return Column(
                    children: [
                      _PendienteCard(pendiente: reportesPendientes[realIndex]),
                      if (realIndex < totalItems - 1)
                        Container(height: 8, color: Colors.grey.shade100),
                    ],
                  );
                }

                // Después: reportes sincronizados
                final reporteIndex = realIndex - reportesPendientes.length;
                return Column(
                  children: [
                    _PostCard(reporte: reportes[reporteIndex]),
                    if (reporteIndex < reportes.length - 1)
                      Container(height: 8, color: Colors.grey.shade100),
                  ],
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANNER DE ALERTAS OFICIALES
// ─────────────────────────────────────────────────────────────────────────────

class _AlertasBanner extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> alertas;

  const _AlertasBanner({required this.alertas});

  @override
  Widget build(BuildContext context) {
    return alertas.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (lista) {
        if (lista.isEmpty) return const SizedBox.shrink();
        final alerta = lista.first;
        final nivel = alerta['nivel_urgencia'] as String? ?? 'informativo';
        final Color bgColor;
        final Color borderColor;
        final IconData icon;

        switch (nivel) {
          case 'critico':
            bgColor = Colors.red.shade50;
            borderColor = Colors.red.shade300;
            icon = Icons.warning_amber_rounded;
          case 'advertencia':
            bgColor = Colors.orange.shade50;
            borderColor = Colors.orange.shade300;
            icon = Icons.info_outline;
          default:
            bgColor = Colors.blue.shade50;
            borderColor = Colors.blue.shade200;
            icon = Icons.campaign_outlined;
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: borderColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alerta['titulo'] as String? ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: borderColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alerta['mensaje'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${lista.length} alerta${lista.length == 1 ? '' : 's'} disponible${lista.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push('/notificaciones'),
                    child: const Text('Ver todas'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER (Esqueleto de carga)
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerFeed extends StatelessWidget {
  const _ShimmerFeed();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: 3,
        separatorBuilder: (_, _) =>
            Container(height: 8, color: Colors.grey.shade100),
        itemBuilder: (_, _) => const _ShimmerCard(),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + líneas de texto
          Row(
            children: [
              const CircleAvatar(radius: 20, backgroundColor: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 20,
                width: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Título
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          // Descripción línea 1
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          // Descripción línea 2
          Container(
            height: 12,
            width: MediaQuery.of(context).size.width * 0.6,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 14),
          // Imagen placeholder
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 14),
          // Botones
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                height: 14,
                width: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                height: 14,
                width: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PENDIENTE CARD (Reporte local sin sincronizar)
// ─────────────────────────────────────────────────────────────────────────────

class _PendienteCard extends StatelessWidget {
  final ReportePendiente pendiente;
  const _PendienteCard({required this.pendiente});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.7,
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icono de reloj
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.schedule,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge "Pendiente de enviar"
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 13,
                            color: Colors.orange.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Pendiente de enviar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Título
                    Text(
                      pendiente.titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Categoría
                    Text(
                      pendiente.categoria,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Descripción
                    Text(
                      pendiente.descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    // Miniatura de foto local (si hay)
                    if (pendiente.listaFotos.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 60,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: pendiente.listaFotos.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (_, i) {
                            final archivo = File(pendiente.listaFotos[i]);
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: archivo.existsSync()
                                  ? Image.file(
                                      archivo,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 24,
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST CARD (Estilo Facebook)
// ─────────────────────────────────────────────────────────────────────────────

class _PostCard extends ConsumerStatefulWidget {
  final Reporte reporte;
  const _PostCard({required this.reporte});

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  late bool _votado;
  late int _conteoVotos;

  @override
  void initState() {
    super.initState();
    _votado = widget.reporte.usuarioHaVotado;
    _conteoVotos = widget.reporte.conteoVotos;
  }

  @override
  void didUpdateWidget(covariant _PostCard old) {
    super.didUpdateWidget(old);
    if (old.reporte.conteoVotos != widget.reporte.conteoVotos ||
        old.reporte.usuarioHaVotado != widget.reporte.usuarioHaVotado) {
      _votado = widget.reporte.usuarioHaVotado;
      _conteoVotos = widget.reporte.conteoVotos;
    }
  }

  Future<void> _toggleVoto() async {
    setState(() {
      _votado = !_votado;
      _conteoVotos += _votado ? 1 : -1;
    });
    try {
      await ref.read(reportesRepositoryProvider).toggleVoto(widget.reporte.id);
    } catch (e) {
      setState(() {
        _votado = !_votado;
        _conteoVotos += _votado ? 1 : -1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al votar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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

  String _tiempoRelativo(DateTime fecha) {
    final d = DateTime.now().difference(fecha);
    if (d.inMinutes < 1) return 'Ahora';
    if (d.inMinutes < 60) return 'Hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'Hace ${d.inHours} h';
    if (d.inDays < 7) return 'Hace ${d.inDays} días';
    if (d.inDays < 30) return 'Hace ${(d.inDays / 7).floor()} sem';
    return 'Hace ${(d.inDays / 30).floor()} meses';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reporte;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () async {
          await context.push('/reporte-detalle', extra: r);
          ref.invalidate(todosReportesProvider);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── HEADER ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      (r.nombreAutor ?? 'U').substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.nombreAutor ?? 'Usuario',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              _tiempoRelativo(r.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                '  •  ${r.colonia.isNotEmpty ? r.colonia : 'Colonia no especificada'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _colorEstado(r.estado).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      r.estado.value,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _colorEstado(r.estado),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── BODY: Categoría + Título + Descripción ─────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      r.categoria.value,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    r.titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.descripcion,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ─── IMÁGENES (Grid estilo Facebook) ────────────────
            if (r.fotosUrls.isNotEmpty)
              ReportImageGrid(fotosUrls: r.fotosUrls),

            // ─── Contadores (likes y comentarios) ────────────────────
            if (_conteoVotos > 0 || r.conteoComentarios > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    if (_conteoVotos > 0) ...[
                      Icon(
                        Icons.thumb_up,
                        size: 14,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_conteoVotos',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (r.conteoComentarios > 0)
                      Text(
                        '${r.conteoComentarios} comentario${r.conteoComentarios == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),

            // ─── FOOTER: Botones de acción ───────────────────────────
            const Divider(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _toggleVoto,
                      icon: Icon(
                        _votado ? Icons.thumb_up_alt : Icons.thumb_up_off_alt,
                        color: _votado ? Colors.blue : Colors.grey.shade600,
                        size: 20,
                      ),
                      label: Text(
                        'Apoyar',
                        style: TextStyle(
                          color: _votado ? Colors.blue : Colors.grey.shade600,
                          fontWeight: _votado
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => mostrarComentarios(context, r.id),
                      icon: Icon(
                        Icons.comment_outlined,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      label: Text(
                        'Comentar',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
