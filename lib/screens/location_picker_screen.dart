import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/cached_tile_layer.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  Timer? _debounceDireccion;

  static const double _radioMaximoGpsMetros = 15000;
  static const double _zoomSeleccion = 17.0;

  // Rectangulo aproximado para limitar la seleccion al municipio de Bochil.
  static final LatLngBounds _bochilBounds = LatLngBounds(
    const LatLng(16.90, -93.00), // southWest
    const LatLng(17.10, -92.75), // northEast
  );

  LatLng _centroActual = bochilCenter;
  bool _cargando = true;
  String _direccionLegible = 'Buscando direccion...';
  String _coloniaDetectada = '';

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  @override
  void dispose() {
    _debounceDireccion?.cancel();
    super.dispose();
  }

  Future<void> _obtenerDireccion(LatLng punto) async {
    try {
      final resultados = await Connectivity().checkConnectivity();
      final hayInternet = !resultados.contains(ConnectivityResult.none);

      if (!hayInternet) {
        if (mounted) {
          setState(() {
            _direccionLegible =
                'Direccion no disponible sin conexion (Ubicacion GPS guardada)';
            _coloniaDetectada = '';
          });
        }
        return;
      }

      final placemarks = await placemarkFromCoordinates(
        punto.latitude,
        punto.longitude,
      );

      if (placemarks.isEmpty) {
        if (mounted) {
          setState(() {
            _direccionLegible = 'Direccion no encontrada para esta ubicacion';
            _coloniaDetectada = '';
          });
        }
        return;
      }

      final p = placemarks.first;
      final partes = [
        p.street,
        p.subLocality,
        p.locality,
      ].where((e) => e != null && e.trim().isNotEmpty).cast<String>().toList();

      if (mounted) {
        setState(() {
          _direccionLegible =
              partes.isNotEmpty ? partes.join(', ') : 'Direccion no encontrada';
          _coloniaDetectada = (p.subLocality ?? '').trim();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _direccionLegible =
              'Direccion no disponible sin conexion (Ubicacion GPS guardada)';
          _coloniaDetectada = '';
        });
      }
    }
  }

  Future<void> _obtenerUbicacion() async {
    try {
      final gpsActivo = await Geolocator.isLocationServiceEnabled();
      if (!gpsActivo) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'El GPS esta desactivado. Usando ubicacion por defecto (Bochil).',
              ),
            ),
          );
          setState(() => _cargando = false);
        }
        await _obtenerDireccion(_centroActual);
        return;
      }

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }

      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        if (permiso == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permiso de ubicacion denegado. Usando ubicacion por defecto (Bochil).',
              ),
            ),
          );
          setState(() => _cargando = false);
        }
        await _obtenerDireccion(_centroActual);
        return;
      }

      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final distanciaABochil = Geolocator.distanceBetween(
        posicion.latitude,
        posicion.longitude,
        bochilCenter.latitude,
        bochilCenter.longitude,
      );

      final centroCalculado = distanciaABochil <= _radioMaximoGpsMetros
          ? LatLng(posicion.latitude, posicion.longitude)
          : bochilCenter;

      if (mounted) {
        setState(() {
          _centroActual = centroCalculado;
          _cargando = false;
        });

        if (distanciaABochil > _radioMaximoGpsMetros) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Estas fuera de la zona de Bochil. Se uso el centro del municipio.',
              ),
            ),
          );
        }

        _mapController.move(_centroActual, _zoomSeleccion);
        await _obtenerDireccion(_centroActual);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo obtener la ubicacion GPS. Usando ubicacion por defecto (Bochil).',
            ),
          ),
        );
        setState(() => _cargando = false);
        await _obtenerDireccion(_centroActual);
      }
    }
  }

  void _confirmarUbicacion() {
    final centro = _mapController.camera.center;

    if (!_bochilBounds.contains(centro)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El reporte debe estar dentro del municipio de Bochil.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    context.push(
      '/report-form',
      extra: {
        'ubicacion': centro,
        'direccionLegible': _direccionLegible,
        'colonia': _coloniaDetectada,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar Ubicación')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Mapa
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _centroActual,
                    initialZoom: _zoomSeleccion,
                    minZoom: 12,
                    cameraConstraint: CameraConstraint.containCenter(
                      bounds: _bochilBounds,
                    ),
                    onPositionChanged: (camera, hasGesture) {
                      if (!hasGesture) return;
                      _debounceDireccion?.cancel();
                      _debounceDireccion = Timer(
                        const Duration(milliseconds: 500),
                        () {
                          _centroActual = camera.center;
                          _obtenerDireccion(_centroActual);
                        },
                      );
                    },
                  ),
                  children: [
                    CachedTileLayerBuilder.build(),
                  ],
                ),

                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 96,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
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
                            _direccionLegible,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Marcador estático en el centro de la pantalla
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.location_on,
                      size: 48,
                      color: AppColors.error,
                    ),
                  ),
                ),

                // Sombra del marcador
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: Colors.black38,
                    ),
                  ),
                ),

                // Botón confirmar
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: ElevatedButton.icon(
                    onPressed: _confirmarUbicacion,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Confirmar Ubicación'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
