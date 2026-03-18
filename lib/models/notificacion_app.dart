enum TipoNotificacionApp {
  alertaOficial('alerta_oficial'),
  estadoReporte('estado_reporte');

  final String value;
  const TipoNotificacionApp(this.value);

  static TipoNotificacionApp fromString(String value) {
    return TipoNotificacionApp.values.firstWhere((e) => e.value == value);
  }
}

class NotificacionApp {
  final String origenId;
  final TipoNotificacionApp tipo;
  final String titulo;
  final String mensaje;
  final DateTime fecha;
  final bool leida;
  final String? reporteId;

  NotificacionApp({
    required this.origenId,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.fecha,
    required this.leida,
    this.reporteId,
  });

  String get keyLectura => '${tipo.value}:$origenId';
}
