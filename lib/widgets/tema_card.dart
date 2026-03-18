import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../models/tema_foro.dart';
import '../providers/providers.dart';

class TemaCard extends ConsumerStatefulWidget {
  final TemaForo tema;

  const TemaCard({
    super.key,
    required this.tema,
  });

  @override
  ConsumerState<TemaCard> createState() => _TemaCardState();
}

class _TemaCardState extends ConsumerState<TemaCard> {
  late bool _votado;
  late int _conteoVotos;

  @override
  void initState() {
    super.initState();
    _votado = widget.tema.usuarioHaVotado;
    _conteoVotos = widget.tema.conteoVotos;
  }

  @override
  void didUpdateWidget(covariant TemaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tema.conteoVotos != widget.tema.conteoVotos ||
        oldWidget.tema.usuarioHaVotado != widget.tema.usuarioHaVotado) {
      _votado = widget.tema.usuarioHaVotado;
      _conteoVotos = widget.tema.conteoVotos;
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

  Future<void> _toggleVoto() async {
    setState(() {
      _votado = !_votado;
      _conteoVotos += _votado ? 1 : -1;
    });

    try {
      await ref.read(foroRepositoryProvider).toggleVotoTema(widget.tema.id);
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

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () async {
          await context.push('/foro/detalle', extra: t);
          ref.invalidate(temasForoProvider);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                    child: Text(
                      (t.nombreAutor ?? 'U').substring(0, 1).toUpperCase(),
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
                          t.nombreAutor ?? 'Usuario',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tiempoRelativo(t.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t.categoria.value,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.contenido,
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
                        'Apoyar ($_conteoVotos)',
                        style: TextStyle(
                          color: _votado ? Colors.blue : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        await context.push('/foro/detalle', extra: t);
                        ref.invalidate(temasForoProvider);
                      },
                      icon: Icon(
                        Icons.comment_outlined,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      label: Text(
                        'Comentar (${t.conteoComentarios})',
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
