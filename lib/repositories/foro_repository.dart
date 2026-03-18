import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tema_foro.dart';

class ForoRepository {
  final SupabaseClient _client;

  ForoRepository(this._client);

  static const _selectColumns =
      'id, usuario_id, titulo, categoria, contenido, votos_apoyo, activo, created_at, updated_at';

  Future<List<TemaForo>> obtenerTemasEnriquecidos() async {
    final userId = _client.auth.currentUser?.id;

    final temasData = await _client
        .from('temas_foro')
        .select('$_selectColumns, autor:perfiles_usuarios!usuario_id(nombre_completo)')
        .eq('activo', true)
        .order('created_at', ascending: false);

    final lista = temasData as List;
    if (lista.isEmpty) return [];

    final ids = lista.map((r) => r['id'] as String).toList();

    final votosData = await _client
        .from('votos_foro')
        .select('tema_id, usuario_id')
        .inFilter('tema_id', ids);

    final Map<String, int> conteoVotos = {};
    final Set<String> misVotos = {};
    for (final v in votosData as List) {
      final tid = v['tema_id'] as String;
      conteoVotos[tid] = (conteoVotos[tid] ?? 0) + 1;
      if (v['usuario_id'] == userId) misVotos.add(tid);
    }

    final comentariosData = await _client
        .from('comentarios_foro')
        .select('tema_id')
        .inFilter('tema_id', ids);

    final Map<String, int> conteoComentarios = {};
    for (final c in comentariosData as List) {
      final tid = c['tema_id'] as String;
      conteoComentarios[tid] = (conteoComentarios[tid] ?? 0) + 1;
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
      return TemaForo.fromJson(json);
    }).toList();
  }

  Future<void> crearTema({
    required String titulo,
    required CategoriaTema categoria,
    required String contenido,
  }) async {
    await _client.from('temas_foro').insert({
      'usuario_id': _client.auth.currentUser!.id,
      'titulo': titulo,
      'categoria': categoria.value,
      'contenido': contenido,
      'activo': true,
    });
  }

  Future<void> eliminarTema(String temaId) async {
    await _client.from('temas_foro').delete().eq('id', temaId);
  }

  Future<bool> yaVotoTema(String temaId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _client
        .from('votos_foro')
        .select()
        .eq('tema_id', temaId)
        .eq('usuario_id', userId)
        .maybeSingle();

    return response != null;
  }

  Future<bool> toggleVotoTema(String temaId) async {
    final userId = _client.auth.currentUser!.id;
    final existe = await yaVotoTema(temaId);

    if (existe) {
      await _client
          .from('votos_foro')
          .delete()
          .eq('tema_id', temaId)
          .eq('usuario_id', userId);
      return false;
    } else {
      await _client.from('votos_foro').insert({
        'tema_id': temaId,
        'usuario_id': userId,
      });
      return true;
    }
  }

  Future<int> contarVotosTema(String temaId) async {
    final response =
        await _client.from('votos_foro').select().eq('tema_id', temaId);
    return (response as List).length;
  }

  Future<List<Map<String, dynamic>>> obtenerComentariosTema(String temaId) async {
    final data = await _client
        .from('comentarios_foro')
        .select(
          'id, comentario, created_at, usuario_id, autor:perfiles_usuarios!usuario_id(nombre_completo)',
        )
        .eq('tema_id', temaId)
        .order('created_at', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> agregarComentarioTema(String temaId, String texto) async {
    await _client.from('comentarios_foro').insert({
      'tema_id': temaId,
      'usuario_id': _client.auth.currentUser!.id,
      'comentario': texto,
    });
  }
}
