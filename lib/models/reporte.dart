import 'package:latlong2/latlong.dart';
import '../core/constants.dart';

class Reporte {
  final String id;
  final String usuarioId;
  final String? asignadoA;
  final String titulo;
  final CategoriaReporte categoria;
  final String descripcion;
  final String colonia;
  final LatLng ubicacion;
  final List<String> fotosUrls;
  final EstadoReporte estado;
  final bool esPublico;
  final int votosApoyo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? nombreAutor;
  final int conteoVotos;
  final bool usuarioHaVotado;
  final int conteoComentarios;

  Reporte({
    required this.id,
    required this.usuarioId,
    this.asignadoA,
    required this.titulo,
    required this.categoria,
    required this.descripcion,
    required this.colonia,
    required this.ubicacion,
    required this.fotosUrls,
    required this.estado,
    this.esPublico = true,
    required this.votosApoyo,
    required this.createdAt,
    required this.updatedAt,
    this.nombreAutor,
    this.conteoVotos = 0,
    this.usuarioHaVotado = false,
    this.conteoComentarios = 0,
  });

  factory Reporte.fromJson(Map<String, dynamic> json) {
    final lat = (json['latitud'] as num?)?.toDouble() ?? 0.0;
    final lon = (json['longitud'] as num?)?.toDouble() ?? 0.0;

    final fotosRaw = json['fotos_urls'];
    final List<String> fotos = fotosRaw is List
        ? fotosRaw.cast<String>()
        : <String>[];

    return Reporte(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String,
      asignadoA: json['asignado_a'] as String?,
      titulo: json['titulo'] as String,
      categoria: CategoriaReporte.fromString(json['categoria'] as String),
      descripcion: json['descripcion'] as String,
      colonia: json['colonia'] as String,
      ubicacion: LatLng(lat, lon),
      fotosUrls: fotos,
      estado: EstadoReporte.fromString(json['estado'] as String),
      esPublico: json['es_publico'] as bool? ?? true,
      votosApoyo: (json['votos_apoyo'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      nombreAutor: json['nombre_autor'] as String?,
      conteoVotos: (json['conteo_votos'] as num?)?.toInt() ?? 0,
      usuarioHaVotado: json['usuario_ha_votado'] as bool? ?? false,
      conteoComentarios: (json['conteo_comentarios'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usuario_id': usuarioId,
      'titulo': titulo,
      'categoria': categoria.value,
      'descripcion': descripcion,
      'colonia': colonia,
      'ubicacion': 'POINT(${ubicacion.longitude} ${ubicacion.latitude})',
      'fotos_urls': fotosUrls,
      'estado': estado.value,
      'es_publico': esPublico,
    };
  }

  /// Serialización completa para caché local (incluye todos los campos).
  Map<String, dynamic> toJsonCompleto() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'asignado_a': asignadoA,
      'titulo': titulo,
      'categoria': categoria.value,
      'descripcion': descripcion,
      'colonia': colonia,
      'latitud': ubicacion.latitude,
      'longitud': ubicacion.longitude,
      'fotos_urls': fotosUrls,
      'estado': estado.value,
      'es_publico': esPublico,
      'votos_apoyo': votosApoyo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'nombre_autor': nombreAutor,
      'conteo_votos': conteoVotos,
      'usuario_ha_votado': usuarioHaVotado,
      'conteo_comentarios': conteoComentarios,
    };
  }
}
