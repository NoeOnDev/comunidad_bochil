import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notificacion_app.dart';

class NotificacionesRepository {
  final SupabaseClient _client;

  NotificacionesRepository(this._client);

  Future<List<NotificacionApp>> obtenerNotificaciones() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final calleUsuario = await _obtenerCalleUsuario(userId);
    final calleUsuarioNormalizada = _normalizarTexto(calleUsuario);

    final lecturasData = await _client
        .from('notificaciones_lecturas')
        .select('tipo, origen_id')
        .eq('usuario_id', userId);

    final leidas = <String>{};
    for (final l in lecturasData as List) {
      final tipo = l['tipo'] as String;
      final origenId = l['origen_id'] as String;
      leidas.add('$tipo:$origenId');
    }

    List alertasData;
    bool alertaIncluyeCalles = true;
    try {
      alertasData = await _client
          .from('alertas_oficiales')
          .select('id, titulo, mensaje, created_at, aplica_todas_calles, calles_objetivo')
          .order('created_at', ascending: false) as List;
    } catch (_) {
      alertaIncluyeCalles = false;
      alertasData = await _client
          .from('alertas_oficiales')
          .select('id, titulo, mensaje, created_at')
          .order('created_at', ascending: false) as List;
    }

    final reportesData = await _client
        .from('reportes')
        .select('id, titulo')
        .eq('usuario_id', userId);

    final reportes = reportesData as List;
    final reportesIds = reportes.map((r) => r['id'] as String).toList();
    final tituloPorReporte = <String, String>{
      for (final r in reportes)
        r['id'] as String: (r['titulo'] as String? ?? 'Reporte')
    };

    List historialData = [];
    if (reportesIds.isNotEmpty) {
      historialData = await _client
          .from('historial_estados')
          .select('id, reporte_id, estado_nuevo, created_at')
          .inFilter('reporte_id', reportesIds)
          .order('created_at', ascending: false) as List;
    }

    final notificaciones = <NotificacionApp>[];

    for (final a in alertasData) {
      if (alertaIncluyeCalles &&
          !_debeMostrarAlertaPorCalle(
            alerta: a as Map<String, dynamic>,
            calleUsuarioNormalizada: calleUsuarioNormalizada,
          )) {
        continue;
      }

      final origenId = a['id'] as String;
      final tipo = TipoNotificacionApp.alertaOficial;
      notificaciones.add(
        NotificacionApp(
          origenId: origenId,
          tipo: tipo,
          titulo: a['titulo'] as String? ?? 'Alerta oficial',
          mensaje: a['mensaje'] as String? ?? '',
          fecha: DateTime.parse(a['created_at'] as String),
          leida: leidas.contains('${tipo.value}:$origenId'),
        ),
      );
    }

    for (final h in historialData) {
      final origenId = h['id'] as String;
      final tipo = TipoNotificacionApp.estadoReporte;
      final reporteId = h['reporte_id'] as String;
      final tituloReporte = tituloPorReporte[reporteId] ?? 'Reporte';
      final estadoNuevo = h['estado_nuevo'] as String? ?? 'Actualizado';

      notificaciones.add(
        NotificacionApp(
          origenId: origenId,
          tipo: tipo,
          titulo: 'Actualización de tu reporte',
          mensaje: '"$tituloReporte" cambió a estado: $estadoNuevo',
          fecha: DateTime.parse(h['created_at'] as String),
          leida: leidas.contains('${tipo.value}:$origenId'),
          reporteId: reporteId,
        ),
      );
    }

    notificaciones.sort((a, b) => b.fecha.compareTo(a.fecha));
    return notificaciones;
  }

  Future<void> marcarLeida(NotificacionApp notificacion) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('notificaciones_lecturas').upsert(
      {
        'usuario_id': userId,
        'tipo': notificacion.tipo.value,
        'origen_id': notificacion.origenId,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'usuario_id,tipo,origen_id',
    );
  }

  Future<void> marcarTodasLeidas(List<NotificacionApp> notificaciones) async {
    for (final n in notificaciones.where((n) => !n.leida)) {
      await marcarLeida(n);
    }
  }

  Future<String?> _obtenerCalleUsuario(String userId) async {
    try {
      final perfil = await _client
          .from('perfiles_usuarios')
          .select('calle')
          .eq('id', userId)
          .maybeSingle();

      return (perfil?['calle'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }

  bool _debeMostrarAlertaPorCalle({
    required Map<String, dynamic> alerta,
    required String calleUsuarioNormalizada,
  }) {
    final aplicaTodas = alerta['aplica_todas_calles'] == true;
    if (aplicaTodas) return true;

    final callesRaw = alerta['calles_objetivo'];
    if (callesRaw is! List) return true;

    final callesObjetivo = callesRaw
        .whereType<String>()
        .map(_normalizarTexto)
        .where((c) => c.isNotEmpty)
        .toSet();

    if (callesObjetivo.isEmpty) return true;
    if (calleUsuarioNormalizada.isEmpty) return false;

    return callesObjetivo.contains(calleUsuarioNormalizada);
  }

  String _normalizarTexto(String? value) {
    if (value == null) return '';
    return value.trim().toLowerCase();
  }
}
