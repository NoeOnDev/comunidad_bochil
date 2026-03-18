class TemaForo {
  final String id;
  final String usuarioId;
  final String titulo;
  final CategoriaTema categoria;
  final String contenido;
  final int votosApoyo;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? nombreAutor;
  final int conteoVotos;
  final bool usuarioHaVotado;
  final int conteoComentarios;

  TemaForo({
    required this.id,
    required this.usuarioId,
    required this.titulo,
    required this.categoria,
    required this.contenido,
    required this.votosApoyo,
    required this.activo,
    required this.createdAt,
    required this.updatedAt,
    this.nombreAutor,
    this.conteoVotos = 0,
    this.usuarioHaVotado = false,
    this.conteoComentarios = 0,
  });

  factory TemaForo.fromJson(Map<String, dynamic> json) {
    return TemaForo(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String,
      titulo: json['titulo'] as String,
      categoria: CategoriaTema.fromString(json['categoria'] as String),
      contenido: json['contenido'] as String,
      votosApoyo: (json['votos_apoyo'] as num?)?.toInt() ?? 0,
      activo: json['activo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      nombreAutor: json['nombre_autor'] as String?,
      conteoVotos: (json['conteo_votos'] as num?)?.toInt() ?? 0,
      usuarioHaVotado: json['usuario_ha_votado'] as bool? ?? false,
      conteoComentarios: (json['conteo_comentarios'] as num?)?.toInt() ?? 0,
    );
  }
}

enum CategoriaTema {
  propuesta('Propuesta'),
  pregunta('Pregunta'),
  discusion('Discusion'),
  anuncio('Anuncio');

  final String value;
  const CategoriaTema(this.value);

  static CategoriaTema fromString(String value) {
    return CategoriaTema.values.firstWhere((e) => e.value == value);
  }
}
