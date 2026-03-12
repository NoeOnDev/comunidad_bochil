import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';

/// Crea un [TileLayer] con caché persistente para tiles de OpenStreetMap.
/// Las teselas visitadas se guardan en el dispositivo y se muestran offline.
class CachedTileLayerBuilder {
  static CacheStore? _cacheStore;

  /// Inicializa el store de caché. Llamar una vez al iniciar la app.
  static Future<void> init() async {
    final dir = await getApplicationCacheDirectory();
    _cacheStore = HiveCacheStore(
      '${dir.path}/map_tiles',
      hiveBoxName: 'map_tiles_cache',
    );
  }

  /// Retorna un [TileLayer] con caché.
  /// Si el store no fue inicializado, retorna un TileLayer normal.
  static TileLayer build() {
    if (_cacheStore == null) {
      return TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.sapam.comunidad_bochil',
      );
    }

    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.sapam.comunidad_bochil',
      tileProvider: CachedTileProvider(
        store: _cacheStore!,
      ),
    );
  }
}
