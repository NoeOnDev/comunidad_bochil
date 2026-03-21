class PerfilUsuario {
  final String id;
  final String rol;
  final String nombreCompleto;
  final String curp;
  final String? numeroContrato;
  final String? direccion;
  final String? colonia;
  final String? calle;
  final String? email;
  final String telefono;
  final String? invitacionId;
  final DateTime createdAt;

  PerfilUsuario({
    required this.id,
    required this.rol,
    required this.nombreCompleto,
    required this.curp,
    this.numeroContrato,
    this.direccion,
    this.colonia,
    this.calle,
    this.email,
    required this.telefono,
    this.invitacionId,
    required this.createdAt,
  });

  factory PerfilUsuario.fromJson(Map<String, dynamic> json) {
    return PerfilUsuario(
      id: json['id'] as String,
      rol: json['rol'] as String,
      nombreCompleto: json['nombre_completo'] as String,
      curp: json['curp'] as String,
      numeroContrato: json['numero_contrato'] as String?,
      direccion: json['direccion'] as String?,
      colonia: json['colonia'] as String?,
      calle: json['calle'] as String?,
      email: json['email'] as String?,
      telefono: json['telefono'] as String,
      invitacionId: json['invitacion_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rol': rol,
      'nombre_completo': nombreCompleto,
      'curp': curp,
      'numero_contrato': numeroContrato,
      'direccion': direccion,
      'colonia': colonia,
      'calle': calle,
      'email': email,
      'telefono': telefono,
      'invitacion_id': invitacionId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
