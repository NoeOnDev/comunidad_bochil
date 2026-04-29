import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../models/reporte.dart';
import '../models/historial_estado.dart';

class ReportesRepository {
  final SupabaseClient _client;

  ReportesRepository(this._client);

  static const _selectColumns =
      'id, usuario_id, asignado_a, titulo, categoria, descripcion, '
      'colonia, latitud, longitud, fotos_urls, estado, es_publico, votos_apoyo, '
      'created_at, updated_at';

  Future<Map<String, String>> _obtenerNombresPublicos(
    List<String> usuariosIds,
  ) async {
    final idsUnicos = usuariosIds.toSet().toList();
    if (idsUnicos.isEmpty) return {};

    final data = await _client
        .from('perfiles_publicos')
        .select('id, nombre_completo')
        .inFilter('id', idsUnicos);

    final mapa = <String, String>{};
    for (final row in data as List) {
      final id = row['id'] as String?;
      final nombre = row['nombre_completo'] as String?;
      if (id != null && nombre != null && nombre.trim().isNotEmpty) {
        mapa[id] = nombre;
      }
    }
    return mapa;
  }

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

    // 1. Reportes públicos
    final reportesData = await _client
        .from('reportes')
        .select(_selectColumns)
        .eq('es_publico', true)
        .order('created_at', ascending: false);

    final lista = reportesData as List;
    if (lista.isEmpty) return [];

    final ids = lista.map((r) => r['id'] as String).toList();

    final autorIds = lista.map((r) => r['usuario_id'] as String).toList();
    final nombresAutores = await _obtenerNombresPublicos(autorIds);

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
      final autorId = json['usuario_id'] as String;
      json['nombre_autor'] = nombresAutores[autorId];
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

    await _client.storage
        .from('evidencia_reportes')
        .upload(
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
    String reporteId,
  ) async {
    final data = await _client
        .from('comentarios_reportes')
        .select('id, comentario, created_at, usuario_id')
        .eq('reporte_id', reporteId)
        .order('created_at', ascending: true);

    final comentarios = (data as List).cast<Map<String, dynamic>>();
    final autorIds = comentarios
        .map((c) => c['usuario_id'] as String?)
        .whereType<String>()
        .toList();
    final nombresAutores = await _obtenerNombresPublicos(autorIds);

    return comentarios.map((c) {
      final autorId = c['usuario_id'] as String?;
      return {
        ...c,
        'autor': {
          'nombre_completo': autorId != null
              ? (nombresAutores[autorId] ?? 'Usuario')
              : 'Usuario',
        },
      };
    }).toList();
  }

  /// Agrega un comentario a un reporte.
  Future<void> agregarComentario(String reporteId, String texto) async {
    await _client.from('comentarios_reportes').insert({
      'reporte_id': reporteId,
      'usuario_id': _client.auth.currentUser!.id,
      'comentario': texto,
    });
  }

  Future<void> actualizarEstadoOperativo({
    required String reporteId,
    required EstadoReporte estadoActual,
    required EstadoReporte estadoNuevo,
    String? comentario,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Debes iniciar sesión para actualizar el reporte.');
    }

    final perfil = await _client
        .from('perfiles_usuarios')
        .select('rol')
        .eq('id', userId)
        .maybeSingle();

    final reporte = await _client
        .from('reportes')
        .select('asignado_a')
        .eq('id', reporteId)
        .maybeSingle();

    if (reporte == null) {
      throw StateError('No se encontró el reporte que intentas actualizar.');
    }

    final rol = perfil?['rol'] as String?;
    final asignadoA = reporte['asignado_a'] as String?;
    final puedeEditar =
        asignadoA == userId || rol == 'admin' || rol == 'coordinador';

    if (!puedeEditar) {
      throw StateError('No tienes permisos para actualizar este reporte.');
    }

    if (estadoActual == estadoNuevo) {
      throw StateError('Selecciona un estado distinto para continuar.');
    }

    await _client.from('historial_estados').insert({
      'reporte_id': reporteId,
      'estado_anterior': estadoActual.value,
      'estado_nuevo': estadoNuevo.value,
      'cambiado_por': userId,
      'comentario': (comentario != null && comentario.trim().isNotEmpty)
          ? comentario.trim()
          : null,
    });

    await _client
        .from('reportes')
        .update({
          'estado': estadoNuevo.value,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', reporteId);
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

  /// Obtiene el historial cronológico de cambios de estado de un reporte.
  Future<List<HistorialEstado>> obtenerHistorialEstados(
    String reporteId,
  ) async {
    final data = await _client
        .from('historial_estados')
        .select(
          'id, reporte_id, estado_anterior, estado_nuevo, cambiado_por, comentario, created_at',
        )
        .eq('reporte_id', reporteId)
        .order('created_at', ascending: true);

    return (data as List)
        .map((json) => HistorialEstado.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene un reporte enriquecido por ID para navegación desde notificaciones.
  Future<Reporte?> obtenerReporteEnriquecidoPorId(String reporteId) async {
    final userId = _client.auth.currentUser?.id;

    final raw = await _client
        .from('reportes')
        .select(_selectColumns)
        .eq('id', reporteId)
        .maybeSingle();

    if (raw == null) return null;

    final votosData = await _client
        .from('votos_reportes')
        .select('usuario_id')
        .eq('reporte_id', reporteId);

    final conteoVotos = (votosData as List).length;
    final usuarioHaVotado = votosData.any((v) => v['usuario_id'] == userId);

    final comentariosData = await _client
        .from('comentarios_reportes')
        .select('id')
        .eq('reporte_id', reporteId);

    final conteoComentarios = (comentariosData as List).length;

    final json = Map<String, dynamic>.from(raw as Map);
    final autorId = json['usuario_id'] as String?;
    if (autorId != null) {
      final nombres = await _obtenerNombresPublicos([autorId]);
      json['nombre_autor'] = nombres[autorId];
    }
    json['conteo_votos'] = conteoVotos;
    json['usuario_ha_votado'] = usuarioHaVotado;
    json['conteo_comentarios'] = conteoComentarios;

    return Reporte.fromJson(json);
  }

  /// Obtiene los reportes asignados al usuario autenticado.
  Future<List<Reporte>> obtenerReportesAsignados() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final reportesData = await _client
        .from('reportes')
        .select(_selectColumns)
        .eq('asignado_a', userId)
        .order('updated_at', ascending: false);

    final lista = reportesData as List;
    if (lista.isEmpty) return [];

    final ids = lista.map((r) => r['id'] as String).toList();
    final autorIds = lista.map((r) => r['usuario_id'] as String).toList();
    final nombresAutores = await _obtenerNombresPublicos(autorIds);

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
      final autorId = json['usuario_id'] as String;
      json['nombre_autor'] = nombresAutores[autorId];
      json['conteo_votos'] = conteoVotos[id] ?? 0;
      json['usuario_ha_votado'] = misVotos.contains(id);
      json['conteo_comentarios'] = conteoComentarios[id] ?? 0;
      return Reporte.fromJson(json);
    }).toList();
  }

  // ─── Todos los reportes enriquecidos (para tabs Mi Colonia / Mis Reportes) ─

  /// Obtiene TODOS los reportes enriquecidos con autor, votos y comentarios.
  /// Se filtra localmente por tab (Recientes, Mi Colonia, Mis Reportes).
  Future<List<Reporte>> obtenerTodosReportesEnriquecidos() async {
    final userId = _client.auth.currentUser?.id;

    final reportesData = await _client
        .from('reportes')
        .select(_selectColumns)
        .order('created_at', ascending: false);

    final lista = reportesData as List;
    if (lista.isEmpty) return [];

    final ids = lista.map((r) => r['id'] as String).toList();
    final autorIds = lista.map((r) => r['usuario_id'] as String).toList();
    final nombresAutores = await _obtenerNombresPublicos(autorIds);

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
      final autorId = json['usuario_id'] as String;
      json['nombre_autor'] = nombresAutores[autorId];
      json['conteo_votos'] = conteoVotos[id] ?? 0;
      json['usuario_ha_votado'] = misVotos.contains(id);
      json['conteo_comentarios'] = conteoComentarios[id] ?? 0;
      return Reporte.fromJson(json);
    }).toList();
  }
}
