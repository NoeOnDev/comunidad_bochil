import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../models/reporte.dart';

class ReportesRepository {
  final SupabaseClient _client;

  ReportesRepository(this._client);

  /// Obtiene todos los reportes para mostrar en el mapa.
  /// Selecciona columnas explícitas usando latitud/longitud calculadas (evita WKB de PostGIS).
  Future<List<Reporte>> obtenerReportes() async {
    final response = await _client
        .from('reportes')
        .select(
          'id, usuario_id, asignado_a, titulo, categoria, descripcion, '
          'colonia, latitud, longitud, fotos_urls, estado, votos_apoyo, '
          'created_at, updated_at',
        )
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Reporte.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Sube una imagen al Storage y retorna la URL pública.
  Future<String> subirFoto(File archivo) async {
    final fileName =
        '${_client.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await _client.storage.from('evidencia_reportes').upload(
          fileName,
          archivo,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    final url = _client.storage
        .from('evidencia_reportes')
        .getPublicUrl(fileName);

    return url;
  }

  /// Crea un nuevo reporte con ubicación PostGIS.
  Future<void> crearReporte({
    required String titulo,
    required String categoria,
    required String descripcion,
    required String colonia,
    required LatLng ubicacion,
    required List<String> fotosUrls,
  }) async {
    await _client.from('reportes').insert({
      'usuario_id': _client.auth.currentUser!.id,
      'titulo': titulo,
      'categoria': categoria,
      'descripcion': descripcion,
      'colonia': colonia,
      'ubicacion': 'POINT(${ubicacion.longitude} ${ubicacion.latitude})',
      'fotos_urls': fotosUrls,
      'estado': 'Pendiente',
    });
  }
}
