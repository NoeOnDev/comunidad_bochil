import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import '../repositories/reportes_repository.dart';
import '../models/invitacion_qr.dart';
import '../models/perfil_usuario.dart';
import '../models/reporte.dart';
import '../services/cache_service.dart';

// ─── Supabase Client ─────────────────────────────────────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

// ─── Repositorios ────────────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final reportesRepositoryProvider = Provider<ReportesRepository>(
  (ref) => ReportesRepository(ref.watch(supabaseClientProvider)),
);

// ─── Estado de Autenticación ─────────────────────────────────────────────────
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

// ─── Invitación QR en proceso de registro ────────────────────────────────────
final invitacionEnProcesoProvider = StateProvider<InvitacionQr?>((ref) => null);

/// Teléfono capturado durante el flujo de registro.
final telefonoRegistroProvider = StateProvider<String>((ref) => '');

// ─── Perfil del usuario actual ───────────────────────────────────────────────
final perfilUsuarioProvider = FutureProvider<PerfilUsuario?>((ref) async {
  try {
    final perfil = await ref.watch(authRepositoryProvider).obtenerPerfil();
    if (perfil != null) await CacheService.guardarPerfil(perfil);
    return perfil;
  } catch (e) {
    final cacheado = await CacheService.obtenerPerfilCacheado();
    if (cacheado != null) return cacheado;
    rethrow;
  }
});

// ─── Lista de Reportes ───────────────────────────────────────────────────────
final reportesProvider = FutureProvider<List<Reporte>>((ref) async {
  try {
    final reportes = await ref
        .watch(reportesRepositoryProvider)
        .obtenerReportes();
    await CacheService.guardarReportes(reportes);
    return reportes;
  } catch (e) {
    final cacheados = await CacheService.obtenerReportesCacheados();
    if (cacheados != null) return cacheados;
    rethrow;
  }
});

// ─── Feed Comunitario (solo reportes públicos) ───────────────────────────────
final feedComunitarioProvider = FutureProvider<List<Reporte>>((ref) async {
  return ref.watch(reportesRepositoryProvider).obtenerReportesPublicos();
});

// ─── Todos los Reportes Enriquecidos (para tabs filtro) ──────────────────────
final todosReportesProvider = FutureProvider<List<Reporte>>((ref) async {
  try {
    final reportes = await ref
        .watch(reportesRepositoryProvider)
        .obtenerTodosReportesEnriquecidos();
    await CacheService.guardarReportesEnriquecidos(reportes);
    return reportes;
  } catch (e) {
    final cacheados = await CacheService.obtenerReportesEnriquecidosCacheados();
    if (cacheados != null) return cacheados;
    rethrow;
  }
});

// ─── Alertas Oficiales ───────────────────────────────────────────────────────
final alertasProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(reportesRepositoryProvider).obtenerAlertasActivas();
});
