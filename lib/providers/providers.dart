import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import '../repositories/reportes_repository.dart';
import '../models/invitacion_qr.dart';
import '../models/reporte.dart';

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

// ─── Lista de Reportes ───────────────────────────────────────────────────────
final reportesProvider = FutureProvider<List<Reporte>>((ref) async {
  return ref.watch(reportesRepositoryProvider).obtenerReportes();
});
