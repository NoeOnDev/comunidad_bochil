import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import '../repositories/foro_repository.dart';
import '../repositories/notificaciones_repository.dart';
import '../repositories/reportes_repository.dart';
import '../models/invitacion_qr.dart';
import '../models/perfil_usuario.dart';
import '../models/reporte.dart';
import '../models/tema_foro.dart';
import '../models/notificacion_app.dart';
import '../models/filtros_reporte.dart';
import '../models/historial_estado.dart';
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

final foroRepositoryProvider = Provider<ForoRepository>(
  (ref) => ForoRepository(ref.watch(supabaseClientProvider)),
);

final notificacionesRepositoryProvider = Provider<NotificacionesRepository>(
  (ref) => NotificacionesRepository(ref.watch(supabaseClientProvider)),
);

// ─── Estado de Autenticación ─────────────────────────────────────────────────
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

/// Usuario de Auth sincronizado desde servidor.
/// Se usa para reflejar cambios de email/magic link en el primer retorno.
final authUserServerProvider = FutureProvider<User?>((ref) async {
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);

  try {
    final response = await client.auth.getUser();
    return response.user ?? client.auth.currentUser;
  } catch (_) {
    return client.auth.currentUser;
  }
});

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

// ─── Filtros del feed comunitario ───────────────────────────────────────────
final filtrosReportesProvider = StateProvider<FiltrosReporte>(
  (ref) => const FiltrosReporte(),
);

final reportesFiltradosProvider = Provider<AsyncValue<List<Reporte>>>((ref) {
  final reportesAsync = ref.watch(todosReportesProvider);
  final filtros = ref.watch(filtrosReportesProvider);
  return reportesAsync.whenData(filtros.aplicar);
});

final misReportesAsignadosProvider = FutureProvider<List<Reporte>>((ref) async {
  return ref.watch(reportesRepositoryProvider).obtenerReportesAsignados();
});

// ─── Historial de estados por reporte (SLA / timeline) ─────────────────────
final historialEstadosProvider =
    FutureProvider.family<List<HistorialEstado>, String>((ref, reporteId) {
      return ref
          .watch(reportesRepositoryProvider)
          .obtenerHistorialEstados(reporteId);
    });

// ─── Alertas Oficiales ───────────────────────────────────────────────────────
final alertasProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(reportesRepositoryProvider).obtenerAlertasActivas();
});

final temasForoProvider = FutureProvider<List<TemaForo>>((ref) async {
  return ref.watch(foroRepositoryProvider).obtenerTemasEnriquecidos();
});

final comentariosTemaProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, temaId) {
      return ref.watch(foroRepositoryProvider).obtenerComentariosTema(temaId);
    });

final notificacionesProvider = FutureProvider<List<NotificacionApp>>((ref) {
  return ref.watch(notificacionesRepositoryProvider).obtenerNotificaciones();
});

final reporteDetallePorIdProvider = FutureProvider.family<Reporte?, String>((
  ref,
  reporteId,
) {
  return ref
      .watch(reportesRepositoryProvider)
      .obtenerReporteEnriquecidoPorId(reporteId);
});
