import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/tema_foro.dart';
import '../providers/providers.dart';

class CrearTemaScreen extends ConsumerStatefulWidget {
  const CrearTemaScreen({super.key});

  @override
  ConsumerState<CrearTemaScreen> createState() => _CrearTemaScreenState();
}

class _CrearTemaScreenState extends ConsumerState<CrearTemaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _contenidoController = TextEditingController();
  CategoriaTema _categoria = CategoriaTema.propuesta;
  bool _guardando = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _contenidoController.dispose();
    super.dispose();
  }

  Future<void> _crearTema() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      await ref.read(foroRepositoryProvider).crearTema(
            titulo: _tituloController.text.trim(),
            categoria: _categoria,
            contenido: _contenidoController.text.trim(),
          );

      if (!mounted) return;
      ref.invalidate(temasForoProvider);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tema creado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo crear el tema: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo tema de foro')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<CategoriaTema>(
                  initialValue: _categoria,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: CategoriaTema.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _categoria = value);
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _tituloController,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return 'Ingresa un título';
                    if (text.length < 6) return 'Usa al menos 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contenidoController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Contenido',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return 'Escribe el contenido del tema';
                    if (text.length < 12) {
                      return 'Usa al menos 12 caracteres para contexto';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _guardando ? null : _crearTema,
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_guardando ? 'Publicando...' : 'Publicar tema'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
