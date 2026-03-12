import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../models/reporte.dart';

class ReportesRepository {
  final SupabaseClient _client;

  ReportesRepository(this._client);

  static const _selectColumns =
      'id, usuario_id, asignado_a, titulo, categoria, descripcion, '
      'colonia, latitud, longitud, fotos_urls, estado, es_publico, votos_apoyo, '
      'created_at, updated_at';

  /// Obtiene todos los reportes para mostrar en el mapa.
  Future<List<Reporte>> obtenerReportes() async {
    final response = await _client
        .from('reportes')
        .select(_selectColumns)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Reporte.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene solo reportes públicos para el Feed Comunitario,
  /// enriquecidos con datos del autor, votos y comentarios.
  Future<List<Reporte>> obtenerReportesPublicos() async {
    final userId = _client.auth.currentUser?.id;

    // 1. Reportes públicos con nombre del autor
    final reportesData = await _client
        .from('reportes')
        .select('$_selectColumns, autor:perfiles_usuarios!usuario_id(nombre_completo)')
        .eq('es_publico', true)
        .order('created_at', ascending: false);

    final lista = reportesData as List;
    if (lista.isEmpty) return [];

    final ids = lista.map((r) => r['id'] as String).toList();

    // 2. Todos los votos de estos reportes (una sola consulta)
    final votosData = await _client
        .from('votos_reportes')
        .select('reporte_id, usuario_id')
        .inFilter('reporte_id', ids);

    final Map<String, int> conteoVotos = {};
    final Set<String> misVotos = {};
    for (final v in votosData as List) {
      final rid = v['reporte_id'] as String;
      conteoVotos[rid] = (conteoVotos[rid] ?? 0) + 1;
      if (v['usuario_id'] == userId) misVotos.add(rid);
    }

    // 3. Conteo de comentarios (una sola consulta)
    final comentariosData = await _client
        .from('comentarios_reportes')
        .select('reporte_id')
        .inFilter('reporte_id', ids);

    final Map<String, int> conteoComentarios = {};
    for (final c in comentariosData as List) {
      final rid = c['reporte_id'] as String;
      conteoComentarios[rid] = (conteoComentarios[rid] ?? 0) + 1;
    }

    // 4. Construir lista enriquecida
    return lista.map((raw) {
      final json = Map<String, dynamic>.from(raw as Map);
      final id = json['id'] as String;
      final autorData = json.remove('autor');
      json['nombre_autor'] =
          autorData is Map ? autorData['nombre_completo'] : null;
      json['conteo_votos'] = conteoVotos[id] ?? 0;
      json['usuario_ha_votado'] = misVotos.contains(id);
      json['conteo_comentarios'] = conteoComentarios[id] ?? 0;
      return Reporte.fromJson(json);
    }).toList();
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
    required bool esPublico,
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
      'es_publico': esPublico,
    });
  }

  /// Elimina un reporte por su ID.
  Future<void> eliminarReporte(String reporteId) async {
    await _client.from('reportes').delete().eq('id', reporteId);
  }

  // ─── Sistema de Votos ──────────────────────────────────────────────────────

  /// Obtiene el conteo total de votos para un reporte.
  Future<int> contarVotos(String reporteId) async {
    final response = await _client
        .from('votos_reportes')
        .select()
        .eq('reporte_id', reporteId);
    return (response as List).length;
  }

  /// Verifica si el usuario actual ya votó por un reporte.
  Future<bool> yaVoto(String reporteId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _client
        .from('votos_reportes')
        .select()
        .eq('reporte_id', reporteId)
        .eq('usuario_id', userId)
        .maybeSingle();

    return response != null;
  }

  /// Alterna el voto: si ya votó lo quita, si no lo agrega.
  /// Retorna `true` si después de la acción el usuario tiene voto activo.
  Future<bool> toggleVoto(String reporteId) async {
    final userId = _client.auth.currentUser!.id;
    final existe = await yaVoto(reporteId);

    if (existe) {
      await _client
          .from('votos_reportes')
          .delete()
          .eq('reporte_id', reporteId)
          .eq('usuario_id', userId);
      return false;
    } else {
      await _client.from('votos_reportes').insert({
        'reporte_id': reporteId,
        'usuario_id': userId,
      });
      return true;
    }
  }

  // ─── Sistema de Comentarios ────────────────────────────────────────────────

  /// Obtiene los comentarios de un reporte con datos del autor.
  Future<List<Map<String, dynamic>>> obtenerComentarios(
      String reporteId) async {
    final data = await _client
        .from('comentarios_reportes')
        .select(
            'id, comentario, created_at, usuario_id, autor:perfiles_usuarios!usuario_id(nombre_completo)')
        .eq('reporte_id', reporteId)
        .order('created_at', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Agrega un comentario a un reporte.
  Future<void> agregarComentario(String reporteId, String texto) async {
    await _client.from('comentarios_reportes').insert({
      'reporte_id': reporteId,
      'usuario_id': _client.auth.currentUser!.id,
      'comentario': texto,
    });
  }

  // ─── Alertas Oficiales ─────────────────────────────────────────────────────

  /// Obtiene las alertas oficiales activas.
  Future<List<Map<String, dynamic>>> obtenerAlertasActivas() async {
    final data = await _client
        .from('alertas_oficiales')
        .select('id, titulo, mensaje, nivel_urgencia, created_at')
        .eq('activa', true)
        .order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }

  // ─── Todos los reportes enriquecidos (para tabs Mi Colonia / Mis Reportes) ─

  /// Obtiene TODOS los reportes enriquecidos con autor, votos y comentarios.
  /// Se filtra localmente por tab (Recientes, Mi Colonia, Mis Reportes).
  Future<List<Reporte>> obtenerTodosReportesEnriquecidos() async {
    final userId = _client.auth.currentUser?.id;

    final reportesData = await _client
        .from('reportes')
        .select(
            '$_selectColumns, autor:perfiles_usuarios!usuario_id(nombre_completo)')
        .order('created_at', ascending: false);

    final lista = reportesData as List;
    if (lista.isEmpty) return [];

    final ids = lista.map((r) => r['id'] as String).toList();

    // Votos
    final votosData = await _client
        .from('votos_reportes')
        .select('reporte_id, usuario_id')
        .inFilter('reporte_id', ids);

    final Map<String, int> conteoVotos = {};
    final Set<String> misVotos = {};
    for (final v in votosData as List) {
      final rid = v['reporte_id'] as String;
      conteoVotos[rid] = (conteoVotos[rid] ?? 0) + 1;
      if (v['usuario_id'] == userId) misVotos.add(rid);
    }

    // Comentarios
    final comentariosData = await _client
        .from('comentarios_reportes')
        .select('reporte_id')
        .inFilter('reporte_id', ids);

    final Map<String, int> conteoComentarios = {};
    for (final c in comentariosData as List) {
      final rid = c['reporte_id'] as String;
      conteoComentarios[rid] = (conteoComentarios[rid] ?? 0) + 1;
    }

    return lista.map((raw) {
      final json = Map<String, dynamic>.from(raw as Map);
      final id = json['id'] as String;
      final autorData = json.remove('autor');
      json['nombre_autor'] =
          autorData is Map ? autorData['nombre_completo'] : null;
      json['conteo_votos'] = conteoVotos[id] ?? 0;
      json['usuario_ha_votado'] = misVotos.contains(id);
      json['conteo_comentarios'] = conteoComentarios[id] ?? 0;
      return Reporte.fromJson(json);
    }).toList();
  }
}
