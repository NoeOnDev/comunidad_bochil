import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'core/cached_tile_layer.dart';
import 'router/app_router.dart';
import 'providers/providers.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  await CachedTileLayerBuilder.init();

  runApp(const ProviderScope(child: SapamApp()));
}

class SapamApp extends ConsumerStatefulWidget {
  const SapamApp({super.key});

  @override
  ConsumerState<SapamApp> createState() => _SapamAppState();
}

class _SapamAppState extends ConsumerState<SapamApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciarSyncService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SyncService.instance.dispose();
    super.dispose();
  }

  void _iniciarSyncService() {
    SyncService.instance.onSyncCompleted = () {
      ref.invalidate(reportesProvider);
      ref.invalidate(todosReportesProvider);
    };
    SyncService.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SAPAM Bochil',
      theme: appTheme(),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
