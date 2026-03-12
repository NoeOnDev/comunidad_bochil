import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../repositories/reportes_repository.dart';
import 'local_database_service.dart';

/// Motor de sincronización: escucha cambios de red y sube reportes pendientes.
class SyncService {
  static SyncService? _instance;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _sincronizando = false;

  /// Callbacks opcionales para notificar a la UI.
  VoidCallback? onSyncCompleted;

  SyncService._();

  /// Singleton. Llama a [init] una sola vez desde main().
  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }

  /// Inicia la escucha de cambios de conectividad.
  void init() {
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      final conectado = !result.contains(ConnectivityResult.none);
      if (conectado) {
        sincronizarReportesPendientes();
      }
    });
    // Intento inmediato al iniciar
    sincronizarReportesPendientes();
  }

  /// Detiene la escucha (llamar al cerrar la app, si es necesario).
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Sincroniza todos los reportes de la cola local con Supabase.
  Future<int> sincronizarReportesPendientes() async {
    // Evitar ejecuciones concurrentes
    if (_sincronizando) return 0;
    _sincronizando = true;

    try {
      // Verificar que hay usuario autenticado
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return 0;

      // Verificar conexión
      final resultado = await Connectivity().checkConnectivity();
      if (resultado.contains(ConnectivityResult.none)) return 0;

      final pendientes = await LocalDatabaseService.obtenerPendientes();
      if (pendientes.isEmpty) return 0;

      final repo = ReportesRepository(Supabase.instance.client);
      int sincronizados = 0;

      for (final reporte in pendientes) {
        try {
          // Marcar como "sincronizando" para evitar duplicados
          await LocalDatabaseService.marcarSincronizando(reporte.id!);

          // 1) Subir fotos que aún existan en el dispositivo
          final List<String> fotosUrls = [];
          for (final ruta in reporte.listaFotos) {
            final archivo = File(ruta);
            if (await archivo.exists()) {
              final url = await repo.subirFoto(archivo);
              fotosUrls.add(url);
            }
          }

          // 2) Crear el reporte en Supabase
          await repo.crearReporte(
            titulo: reporte.titulo,
            categoria: reporte.categoria,
            descripcion: reporte.descripcion,
            colonia: reporte.colonia,
            ubicacion: LatLng(reporte.latitud, reporte.longitud),
            fotosUrls: fotosUrls,
            esPublico: reporte.esPublico,
          );

          // 3) Eliminar de la cola local
          await LocalDatabaseService.eliminarPendiente(reporte.id!);

          // 4) Eliminar archivos temporales de fotos
          for (final ruta in reporte.listaFotos) {
            try {
              final archivo = File(ruta);
              if (await archivo.exists()) {
                await archivo.delete();
              }
            } catch (_) {
              // No crítico si no se puede borrar la foto local
            }
          }

          sincronizados++;
        } catch (e) {
          debugPrint('[SyncService] Error al sincronizar reporte ${reporte.id}: $e');
          // Revertir a "pendiente" para reintentar después
          await LocalDatabaseService.revertirAPendiente(reporte.id!);
        }
      }

      if (sincronizados > 0) {
        debugPrint('[SyncService] $sincronizados reportes sincronizados.');
        onSyncCompleted?.call();
      }

      return sincronizados;
    } finally {
      _sincronizando = false;
    }
  }
}
