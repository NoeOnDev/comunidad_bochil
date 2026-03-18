import '../core/constants.dart';

class HistorialEstado {
  final String id;
  final String reporteId;
  final EstadoReporte? estadoAnterior;
  final EstadoReporte estadoNuevo;
  final String? cambiadoPor;
  final String? comentario;
  final DateTime createdAt;

  HistorialEstado({
    required this.id,
    required this.reporteId,
    required this.estadoAnterior,
    required this.estadoNuevo,
    required this.cambiadoPor,
    required this.comentario,
    required this.createdAt,
  });

  factory HistorialEstado.fromJson(Map<String, dynamic> json) {
    final estadoAnteriorRaw = json['estado_anterior'] as String?;
    return HistorialEstado(
      id: json['id'] as String,
      reporteId: json['reporte_id'] as String,
      estadoAnterior:
          estadoAnteriorRaw == null ? null : EstadoReporte.fromString(estadoAnteriorRaw),
      estadoNuevo: EstadoReporte.fromString(json['estado_nuevo'] as String),
      cambiadoPor: json['cambiado_por'] as String?,
      comentario: json['comentario'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
