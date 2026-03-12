import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../providers/providers.dart';

void mostrarComentarios(BuildContext context, String reporteId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ComentariosSheet(reporteId: reporteId),
  );
}

class _ComentariosSheet extends ConsumerStatefulWidget {
  final String reporteId;
  const _ComentariosSheet({required this.reporteId});

  @override
  ConsumerState<_ComentariosSheet> createState() => _ComentariosSheetState();
}

class _ComentariosSheetState extends ConsumerState<_ComentariosSheet> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _comentarios = [];
  bool _cargando = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cargarComentarios();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _cargarComentarios() async {
    try {
      final data = await ref
          .read(reportesRepositoryProvider)
          .obtenerComentarios(widget.reporteId);
      if (mounted) {
        setState(() {
          _comentarios = data;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        final esRed = e is SocketException ||
            e.toString().contains('SocketException') ||
            e.toString().contains('Failed host lookup');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(esRed
                ? 'Sin conexión. No se pudieron cargar los comentarios.'
                : 'Error al cargar comentarios'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _enviarComentario() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;

    setState(() => _enviando = true);
    try {
      await ref
          .read(reportesRepositoryProvider)
          .agregarComentario(widget.reporteId, texto);
      _controller.clear();
      await _cargarComentarios();
      ref.invalidate(todosReportesProvider);
    } catch (e) {
      if (mounted) {
        final esRed = e is SocketException ||
            e.toString().contains('SocketException') ||
            e.toString().contains('Failed host lookup');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(esRed
                ? 'Sin conexión. No se pudo enviar el comentario.'
                : 'Error al comentar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String _tiempoRelativo(DateTime fecha) {
    final d = DateTime.now().difference(fecha);
    if (d.inMinutes < 1) return 'Ahora';
    if (d.inMinutes < 60) return 'Hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'Hace ${d.inHours} h';
    if (d.inDays < 7) return 'Hace ${d.inDays} días';
    final meses = d.inDays ~/ 30;
    return 'Hace ${meses < 1 ? 1 : meses} meses';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          return Column(
            children: [
              // ─── Drag handle ───
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Comentarios',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Divider(),

              // ─── Lista de comentarios ───
              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : _comentarios.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'Sé el primero en comentar',
                                  style:
                                      TextStyle(color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _comentarios.length,
                            itemBuilder: (_, i) =>
                                _buildComentario(_comentarios[i]),
                          ),
              ),

              // ─── Campo de entrada ───
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border:
                      Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Escribe un comentario...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            isDense: true,
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _enviarComentario(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _enviando
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              onPressed: _enviarComentario,
                              icon: const Icon(Icons.send,
                                  color: AppColors.primary),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildComentario(Map<String, dynamic> c) {
    final autorData = c['autor'];
    final nombre = autorData is Map
        ? autorData['nombre_completo'] as String? ?? 'Usuario'
        : 'Usuario';
    final texto = c['comentario'] as String;
    final fecha = DateTime.parse(c['created_at'] as String);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              nombre.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(texto, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    _tiempoRelativo(fecha),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
