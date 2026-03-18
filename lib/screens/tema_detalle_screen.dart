import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/tema_foro.dart';
import '../providers/providers.dart';

class TemaDetalleScreen extends ConsumerStatefulWidget {
  final TemaForo tema;

  const TemaDetalleScreen({super.key, required this.tema});

  @override
  ConsumerState<TemaDetalleScreen> createState() => _TemaDetalleScreenState();
}

class _TemaDetalleScreenState extends ConsumerState<TemaDetalleScreen> {
  late bool _votado;
  late int _conteoVotos;
  final _comentarioController = TextEditingController();
  bool _enviandoComentario = false;

  TemaForo get tema => widget.tema;

  @override
  void initState() {
    super.initState();
    _votado = tema.usuarioHaVotado;
    _conteoVotos = tema.conteoVotos;
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  bool get _puedeEliminar {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return tema.usuarioId == userId;
  }

  Future<void> _toggleVoto() async {
    setState(() {
      _votado = !_votado;
      _conteoVotos += _votado ? 1 : -1;
    });

    try {
      await ref.read(foroRepositoryProvider).toggleVotoTema(tema.id);
      ref.invalidate(temasForoProvider);
    } catch (e) {
      setState(() {
        _votado = !_votado;
        _conteoVotos += _votado ? 1 : -1;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al votar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _agregarComentario() async {
    final texto = _comentarioController.text.trim();
    if (texto.isEmpty) return;

    setState(() => _enviandoComentario = true);
    try {
      await ref.read(foroRepositoryProvider).agregarComentarioTema(tema.id, texto);
      _comentarioController.clear();
      ref.invalidate(comentariosTemaProvider(tema.id));
      ref.invalidate(temasForoProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo publicar el comentario: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _enviandoComentario = false);
    }
  }

  Future<void> _eliminarTema() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tema'),
        content: const Text('Esta acción no se puede deshacer.'),
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

    if (confirmar != true) return;

    try {
      await ref.read(foroRepositoryProvider).eliminarTema(tema.id);
      ref.invalidate(temasForoProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tema eliminado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _tiempoRelativo(DateTime fecha) {
    final d = DateTime.now().difference(fecha);
    if (d.inMinutes < 1) return 'Ahora';
    if (d.inMinutes < 60) return 'Hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'Hace ${d.inHours} h';
    if (d.inDays < 7) return 'Hace ${d.inDays} días';
    return 'Hace ${(d.inDays / 7).floor()} sem';
  }

  @override
  Widget build(BuildContext context) {
    final comentariosAsync = ref.watch(comentariosTemaProvider(tema.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del tema'),
        actions: [
          if (_puedeEliminar)
            IconButton(
              onPressed: _eliminarTema,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar tema',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tema.categoria.value,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tema.titulo,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${tema.nombreAutor ?? 'Usuario'} · ${_tiempoRelativo(tema.createdAt)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tema.contenido,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _toggleVoto,
                    icon: Icon(
                      _votado ? Icons.thumb_up_alt : Icons.thumb_up_off_alt,
                      color: _votado ? Colors.blue : AppColors.textSecondary,
                    ),
                    label: Text(
                      _votado
                          ? 'Has apoyado ($_conteoVotos)'
                          : 'Apoyar ($_conteoVotos)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Comentarios',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  comentariosAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('No se pudieron cargar los comentarios.'),
                    ),
                    data: (comentarios) {
                      if (comentarios.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Sé el primero en comentar este tema.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        );
                      }

                      return Column(
                        children: comentarios.map((c) {
                          final autor = (c['autor'] as Map?)?['nombre_completo'] as String? ??
                              'Usuario';
                          final texto = c['comentario'] as String? ?? '';
                          final fecha = DateTime.tryParse(c['created_at'] as String? ?? '');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  autor,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  fecha == null ? '' : _tiempoRelativo(fecha),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  texto,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _comentarioController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un comentario...',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _enviandoComentario ? null : _agregarComentario,
                      icon: _enviandoComentario
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
