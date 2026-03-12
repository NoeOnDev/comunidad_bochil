import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Modelo para un reporte pendiente en la cola de sincronización.
class ReportePendiente {
  final int? id;
  final String titulo;
  final String categoria;
  final String descripcion;
  final String colonia;
  final double latitud;
  final double longitud;
  final bool esPublico;
  final String fotosLocalesPaths; // rutas separadas por comas
  final String estadoSincronizacion; // 'pendiente' | 'sincronizando'
  final String createdAt;

  ReportePendiente({
    this.id,
    required this.titulo,
    required this.categoria,
    required this.descripcion,
    required this.colonia,
    required this.latitud,
    required this.longitud,
    required this.esPublico,
    required this.fotosLocalesPaths,
    this.estadoSincronizacion = 'pendiente',
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'titulo': titulo,
      'categoria': categoria,
      'descripcion': descripcion,
      'colonia': colonia,
      'latitud': latitud,
      'longitud': longitud,
      'es_publico': esPublico ? 1 : 0,
      'fotos_locales_paths': fotosLocalesPaths,
      'estado_sincronizacion': estadoSincronizacion,
      'created_at': createdAt,
    };
  }

  factory ReportePendiente.fromMap(Map<String, dynamic> map) {
    return ReportePendiente(
      id: map['id'] as int?,
      titulo: map['titulo'] as String,
      categoria: map['categoria'] as String,
      descripcion: map['descripcion'] as String,
      colonia: map['colonia'] as String,
      latitud: (map['latitud'] as num).toDouble(),
      longitud: (map['longitud'] as num).toDouble(),
      esPublico: (map['es_publico'] as int) == 1,
      fotosLocalesPaths: map['fotos_locales_paths'] as String,
      estadoSincronizacion: map['estado_sincronizacion'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  /// Devuelve las rutas de fotos como lista.
  List<String> get listaFotos {
    if (fotosLocalesPaths.isEmpty) return [];
    return fotosLocalesPaths.split(',');
  }
}

/// Servicio de base de datos local con sqflite para la cola de sincronización.
class LocalDatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sapam_sync.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            titulo TEXT NOT NULL,
            categoria TEXT NOT NULL,
            descripcion TEXT NOT NULL,
            colonia TEXT NOT NULL,
            latitud REAL NOT NULL,
            longitud REAL NOT NULL,
            es_publico INTEGER NOT NULL DEFAULT 1,
            fotos_locales_paths TEXT NOT NULL DEFAULT '',
            estado_sincronizacion TEXT NOT NULL DEFAULT 'pendiente',
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Inserta un reporte en la cola de sincronización.
  static Future<int> insertarPendiente(ReportePendiente reporte) async {
    final db = await database;
    return db.insert('sync_queue', reporte.toMap());
  }

  /// Obtiene todos los reportes pendientes de sincronizar.
  static Future<List<ReportePendiente>> obtenerPendientes() async {
    final db = await database;
    final maps = await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => ReportePendiente.fromMap(m)).toList();
  }

  /// Obtiene la cantidad de reportes pendientes.
  static Future<int> cantidadPendientes() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM sync_queue');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Marca un reporte como "sincronizando" para evitar duplicados.
  static Future<void> marcarSincronizando(int id) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'estado_sincronizacion': 'sincronizando'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Revierte un reporte a "pendiente" si la sincronización falla.
  static Future<void> revertirAPendiente(int id) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'estado_sincronizacion': 'pendiente'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Elimina un reporte de la cola (tras sincronización exitosa).
  static Future<void> eliminarPendiente(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }
}
