import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/reportes_repository.dart';
import 'package:latlong2/latlong.dart';

class OfflineSyncService {
  static const _key = 'reportes_pendientes';

  /// Verifica si hay conexión a internet.
  static Future<bool> hayConexion() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Guarda un reporte pendiente en almacenamiento local.
  static Future<void> guardarReportePendiente({
    required String titulo,
    required String categoria,
    required String descripcion,
    required String colonia,
    required double latitud,
    required double longitud,
    required List<String> rutasFotos,
    required bool esPublico,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final pendientes = prefs.getStringList(_key) ?? [];

    final reporte = jsonEncode({
      'titulo': titulo,
      'categoria': categoria,
      'descripcion': descripcion,
      'colonia': colonia,
      'latitud': latitud,
      'longitud': longitud,
      'rutas_fotos': rutasFotos,
      'es_publico': esPublico,
      'timestamp': DateTime.now().toIso8601String(),
    });

    pendientes.add(reporte);
    await prefs.setStringList(_key, pendientes);
  }

  /// Retorna la cantidad de reportes pendientes.
  static Future<int> cantidadPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).length;
  }

  /// Sincroniza todos los reportes pendientes con el servidor.
  /// Retorna la cantidad de reportes sincronizados exitosamente.
  static Future<int> sincronizar(ReportesRepository repo) async {
    if (!await hayConexion()) return 0;

    final prefs = await SharedPreferences.getInstance();
    final pendientes = prefs.getStringList(_key) ?? [];
    if (pendientes.isEmpty) return 0;

    int sincronizados = 0;
    final fallidos = <String>[];

    for (final jsonStr in pendientes) {
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final rutasFotos = (data['rutas_fotos'] as List).cast<String>();
        final List<String> fotosUrls = [];

        // Subir fotos que aún existan en el dispositivo
        for (final ruta in rutasFotos) {
          final archivo = File(ruta);
          if (await archivo.exists()) {
            final url = await repo.subirFoto(archivo);
            fotosUrls.add(url);
          }
        }

        // Crear el reporte
        await repo.crearReporte(
          titulo: data['titulo'] as String,
          categoria: data['categoria'] as String,
          descripcion: data['descripcion'] as String,
          colonia: data['colonia'] as String,
          ubicacion: LatLng(
            (data['latitud'] as num).toDouble(),
            (data['longitud'] as num).toDouble(),
          ),
          fotosUrls: fotosUrls,
          esPublico: data['es_publico'] as bool,
        );

        sincronizados++;
      } catch (e) {
        debugPrint('[OfflineSync] Error al sincronizar reporte: $e');
        fallidos.add(jsonStr);
      }
    }

    // Guardar solo los que fallaron para reintentar después
    await prefs.setStringList(_key, fallidos);

    debugPrint(
        '[OfflineSync] Sincronizados: $sincronizados, Fallidos: ${fallidos.length}');
    return sincronizados;
  }
}
