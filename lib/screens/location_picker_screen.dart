import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
  LatLng _centroActual = bochilCenter;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  Future<void> _obtenerUbicacion() async {
    try {
      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }

      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permiso de ubicación denegado. Puedes mover el mapa manualmente.',
              ),
            ),
          );
          setState(() => _cargando = false);
        }
        return;
      }

      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _centroActual = LatLng(posicion.latitude, posicion.longitude);
          _cargando = false;
        });
        _mapController.move(_centroActual, 17.0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación GPS.'),
          ),
        );
        setState(() => _cargando = false);
      }
    }
  }

  void _confirmarUbicacion() {
    final centro = _mapController.camera.center;
    context.push('/report-form', extra: centro);
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
                    initialZoom: 17.0,
                  ),
                  children: [
                    CachedTileLayerBuilder.build(),
                  ],
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
