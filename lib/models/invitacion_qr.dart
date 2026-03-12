class InvitacionQr {
  final String id;
  final String curp;
  final String numeroContrato;
  final String nombreTitular;
  final String direccion;
  final String colonia;
  final bool usado;
  final String? usadoPor;
  final DateTime? fechaUso;
  final DateTime createdAt;

  InvitacionQr({
    required this.id,
    required this.curp,
    required this.numeroContrato,
    required this.nombreTitular,
    required this.direccion,
    required this.colonia,
    required this.usado,
    this.usadoPor,
    this.fechaUso,
    required this.createdAt,
  });

  factory InvitacionQr.fromJson(Map<String, dynamic> json) {
    return InvitacionQr(
      id: json['id'] as String,
      curp: json['curp'] as String,
      numeroContrato: json['numero_contrato'] as String,
      nombreTitular: json['nombre_titular'] as String,
      direccion: json['direccion'] as String,
      colonia: json['colonia'] as String,
      usado: json['usado'] as bool,
      usadoPor: json['usado_por'] as String?,
      fechaUso: json['fecha_uso'] != null
          ? DateTime.parse(json['fecha_uso'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'curp': curp,
      'numero_contrato': numeroContrato,
      'nombre_titular': nombreTitular,
      'direccion': direccion,
      'colonia': colonia,
      'usado': usado,
      'usado_por': usadoPor,
      'fecha_uso': fechaUso?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
