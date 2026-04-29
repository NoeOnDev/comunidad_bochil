import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../models/perfil_usuario.dart';
import '../providers/providers.dart';
import '../services/cache_service.dart';
import '../services/local_database_service.dart';

class ReportFormScreen extends ConsumerStatefulWidget {
  final LatLng ubicacion;
  final String? direccionLegible;
  final String? coloniaSeleccionada;

  const ReportFormScreen({
    super.key,
    required this.ubicacion,
    this.direccionLegible,
    this.coloniaSeleccionada,
  });

  @override
  ConsumerState<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends ConsumerState<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  CategoriaReporte _categoriaSeleccionada = CategoriaReporte.fuga;
  final List<File> _fotos = [];
  bool _enviando = false;
  bool _esPrivado = false;

  static const int _maxFotos = 3;

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  void _mostrarOpcionesFoto() {
    if (_fotos.length >= _maxFotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo $_maxFotos fotos permitidas')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Agregar Foto',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: const Text('Tomar Foto'),
                subtitle: const Text('Usar la cámara del dispositivo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _seleccionarFoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.accent,
                  child: Icon(Icons.photo_library, color: Colors.grey.shade800),
                ),
                title: const Text('Elegir de la Galería'),
                subtitle: const Text('Seleccionar una imagen existente'),
                onTap: () {
                  Navigator.pop(ctx);
                  _seleccionarFoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _seleccionarFoto(ImageSource source) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );

    if (xFile != null && mounted) {
      setState(() => _fotos.add(File(xFile.path)));
    }
  }

  Future<void> _enviarReporte() async {
    if (!_formKey.currentState!.validate()) return;

    final perfil = await ref.read(perfilUsuarioProvider.future);
    if (perfil?.esTecnico ?? false) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tu cuenta de trabajo no puede crear reportes ciudadanos desde esta pantalla.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final hayInternet = await _verificarConexion();

      if (hayInternet) {
        // ─── Flujo normal: subir fotos y crear reporte en Supabase ───
        final reportesRepo = ref.read(reportesRepositoryProvider);
        final List<String> fotosUrls = [];

        for (final foto in _fotos) {
          final url = await reportesRepo.subirFoto(foto);
          fotosUrls.add(url);
        }

        final perfil = await ref.read(authRepositoryProvider).obtenerPerfil();
        final coloniaGeocodificada = widget.coloniaSeleccionada?.trim() ?? '';
        final colonia = coloniaGeocodificada.isNotEmpty
            ? coloniaGeocodificada
            : (perfil?.colonia ?? 'Sin colonia');

        await reportesRepo.crearReporte(
          titulo: _tituloController.text.trim(),
          categoria: _categoriaSeleccionada.value,
          descripcion: _descripcionController.text.trim(),
          colonia: colonia,
          ubicacion: widget.ubicacion,
          fotosUrls: fotosUrls,
          esPublico: !_esPrivado,
        );

        if (!mounted) return;

        ref.invalidate(reportesProvider);
        ref.invalidate(todosReportesProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Reporte enviado exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // ─── Sin internet: guardar en cola local (sqflite) ───
        // Intentar obtener colonia del perfil cacheado (SharedPreferences)
        final perfilCacheado = await CacheService.obtenerPerfilCacheado();
        final coloniaGeocodificada = widget.coloniaSeleccionada?.trim() ?? '';
        final colonia = coloniaGeocodificada.isNotEmpty
            ? coloniaGeocodificada
            : (perfilCacheado?.colonia ?? 'Sin colonia');

        final pendiente = ReportePendiente(
          titulo: _tituloController.text.trim(),
          categoria: _categoriaSeleccionada.value,
          descripcion: _descripcionController.text.trim(),
          colonia: colonia,
          latitud: widget.ubicacion.latitude,
          longitud: widget.ubicacion.longitude,
          esPublico: !_esPrivado,
          fotosLocalesPaths: _fotos.map((f) => f.path).join(','),
        );

        await LocalDatabaseService.insertarPendiente(pendiente);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reporte guardado sin conexión. Se enviará automáticamente '
              'cuando recuperes la señal.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }

      if (mounted) context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar el reporte: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<bool> _verificarConexion() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfilAsync = ref.watch(perfilUsuarioProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Reporte')),
      body: SafeArea(
        child: perfilAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _construirFormulario(),
          data: (perfil) {
            if (perfil?.esTecnico ?? false) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Esta opción no está disponible para tu cuenta de trabajo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tus reportes asignados se gestionan desde el módulo operativo y no desde el formulario ciudadano.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Volver al inicio'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return _construirFormulario();
          },
        ),
      ),
    );
  }

  Widget _construirFormulario() {
    return _enviando
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  'Subiendo fotos y creando reporte...',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Categoría
                  DropdownButtonFormField<CategoriaReporte>(
                    initialValue: _categoriaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Categoría del problema',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: CategoriaReporte.values.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat.value),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _categoriaSeleccionada = v);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Título
                  TextFormField(
                    controller: _tituloController,
                    decoration: const InputDecoration(
                      labelText: 'Título del reporte',
                      prefixIcon: Icon(Icons.title),
                      hintText: 'Ej: Fuga en la calle principal',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Campo requerido'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Descripción
                  TextFormField(
                    controller: _descripcionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      prefixIcon: Icon(Icons.description),
                      hintText: 'Describe el problema con detalle...',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Campo requerido'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Switch de privacidad
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _esPrivado ? Icons.lock : Icons.public,
                          color: _esPrivado
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reporte Privado',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _esPrivado
                                    ? 'Solo visible para el equipo administrador'
                                    : 'Visible en el Feed Comunitario',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _esPrivado,
                          onChanged: (v) => setState(() => _esPrivado = v),
                          activeTrackColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Coordenadas (solo lectura)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.gps_fixed,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lat: ${widget.ubicacion.latitude.toStringAsFixed(6)}, '
                            'Lon: ${widget.ubicacion.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Direccion legible (reverse geocoding)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.direccionLegible ??
                                'Direccion no disponible sin conexion (Ubicacion GPS guardada)',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sección de fotos
                  Row(
                    children: [
                      const Icon(
                        Icons.photo_camera_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Evidencia fotográfica (${_fotos.length}/$_maxFotos)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Grid de miniaturas + botón agregar
                  SizedBox(
                    height: 110,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._fotos.asMap().entries.map((entry) {
                          return _FotoMiniatura(
                            foto: entry.value,
                            onRemove: () {
                              setState(() => _fotos.removeAt(entry.key));
                            },
                          );
                        }),
                        if (_fotos.length < _maxFotos)
                          _BotonAgregarFoto(onTap: _mostrarOpcionesFoto),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botón enviar
                  ElevatedButton.icon(
                    onPressed: _enviarReporte,
                    icon: const Icon(Icons.send),
                    label: const Text('Enviar Reporte'),
                  ),
                ],
              ),
            ),
          );
  }
}

class _FotoMiniatura extends StatelessWidget {
  final File foto;
  final VoidCallback onRemove;

  const _FotoMiniatura({required this.foto, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(foto, width: 100, height: 100, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonAgregarFoto extends StatelessWidget {
  final VoidCallback onTap;

  const _BotonAgregarFoto({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.primary.withValues(alpha: 0.05),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, color: AppColors.primary, size: 28),
            SizedBox(height: 4),
            Text(
              'Agregar',
              style: TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
