import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/env.dart';
import '../models/invitacion_qr.dart';
import '../models/perfil_usuario.dart';
import '../services/push_notification_service.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Valida una invitación QR por su UUID. Retorna null si no existe o ya fue usada.
  Future<InvitacionQr?> validarInvitacion(String qrUuid) async {
    try {
      final response = await _client
          .from('invitaciones_qr')
          .select()
          .eq('id', qrUuid)
          .eq('usado', false)
          .maybeSingle();

      if (response == null) return null;
      return InvitacionQr.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Envía OTP por SMS al número de teléfono.
  Future<void> enviarOtp(String telefono) async {
    try {
      debugPrint('[OTP] Enviando SMS a: $telefono');
      await _client.auth.signInWithOtp(phone: telefono);
      debugPrint('[OTP] SMS enviado exitosamente.');
    } on AuthException catch (e) {
      debugPrint('[OTP] AuthException al enviar SMS: ${e.message} (Status: ${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[OTP] Error general al enviar SMS: $e');
      rethrow;
    }
  }

  /// Verifica el código OTP recibido por SMS.
  Future<AuthResponse> verificarOtp({
    required String telefono,
    required String codigo,
  }) async {
    try {
      debugPrint('[OTP] Verificando código para: $telefono');
      final res = await _client.auth.verifyOTP(
        phone: telefono,
        token: codigo,
        type: OtpType.sms,
      );
      debugPrint('[OTP] Verificación exitosa. User ID: ${res.user?.id}');
      return res;
    } on AuthException catch (e) {
      debugPrint('[OTP] AuthException al verificar código: ${e.message} (Status: ${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[OTP] Error general al verificar: $e');
      rethrow;
    }
  }

  /// Consolida el registro: crea perfil y marca invitación como usada.
  ///
  /// Retorna [true] si todo fue exitoso, o [false] si el perfil fue creado
  /// pero el marcado del QR falló por RLS (requiere corrección SQL en Supabase).
  Future<bool> consolidarRegistro({
    required InvitacionQr invitacion,
    required String telefono,
    String? email,
  }) async {
    final userId = _client.auth.currentUser!.id;

    // 1. Insertar perfil del usuario (operación crítica)
    await _client.from('perfiles_usuarios').insert({
      'id': userId,
      'rol': 'ciudadano',
      'nombre_completo': invitacion.nombreTitular,
      'curp': invitacion.curp,
      'numero_contrato': invitacion.numeroContrato,
      'direccion': invitacion.direccion,
      'colonia': invitacion.colonia,
      'calle_id': invitacion.calleId,
      'email': email,
      'telefono': telefono,
      'invitacion_id': invitacion.id,
    });

    // 2. Marcar la invitación como usada.
    // Nota: si la política SELECT de Supabase solo permite leer filas con
    // usado=false, PostgREST puede lanzar error 42501 al verificar la fila
    // actualizada. El perfil ya fue creado, así que solo logueamos y seguimos.
    try {
      await _client.from('invitaciones_qr').update({
        'usado': true,
        'usado_por': userId,
        'fecha_uso': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', invitacion.id);
      debugPrint('[Registro] QR marcado como usado correctamente.');
      return true;
    } on PostgrestException catch (e) {
      debugPrint(
        '[Registro] Error al marcar QR (código: ${e.code}): ${e.message}. '
        'El usuario ya está autenticado. Aplica el fix de políticas RLS en Supabase.',
      );
      return false;
    }
  }

  /// Envía un enlace mágico de acceso al correo electrónico.
  Future<void> enviarMagicLink(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: Env.magicLinkRedirectUrl,
      shouldCreateUser: false,
    );
  }

  /// Vincula un correo al usuario actual para habilitar recuperación por magic link.
  Future<void> vincularCorreo(String email) async {
    if (_client.auth.currentUser == null) {
      throw const AuthException('No hay sesión activa para vincular correo.');
    }

    await _client.auth.updateUser(
      UserAttributes(email: email),
      emailRedirectTo: Env.magicLinkRedirectUrl,
    );
  }

  /// Obtiene el perfil del usuario actual.
  Future<PerfilUsuario?> obtenerPerfil() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('perfiles_usuarios')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      final perfil = PerfilUsuario.fromJson(response);
      await _sincronizarEmailPerfilConAuth(userId: userId, perfil: perfil);
      return perfil;
    } catch (_) {
      return null;
    }
  }

  Future<void> _sincronizarEmailPerfilConAuth({
    required String userId,
    required PerfilUsuario perfil,
  }) async {
    final authEmail = _client.auth.currentUser?.email?.trim();
    final perfilEmail = perfil.email?.trim();
    if (authEmail == null || authEmail.isEmpty) return;
    if (perfilEmail == authEmail) return;

    try {
      await _client
          .from('perfiles_usuarios')
          .update({'email': authEmail})
          .eq('id', userId);
    } catch (_) {
      // Sin impacto funcional: auth.users es la fuente de verdad del login por email.
    }
  }

  /// Verifica que la sesión local siga siendo válida en Supabase y
  /// que exista perfil asociado en `perfiles_usuarios`.
  Future<bool> sesionSigueValida() async {
    final session = _client.auth.currentSession;
    if (session == null) return false;

    try {
      final authUser = await _client.auth.getUser();
      final userId = authUser.user?.id;
      if (userId == null) return false;

      final perfil = await _client
          .from('perfiles_usuarios')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      return perfil != null;
    } catch (_) {
      return false;
    }
  }

  /// Cierra sesión.
  Future<void> cerrarSesion() async {
    await PushNotificationService.instance.limpiarTokenActual();
    await _client.auth.signOut();
  }
}
