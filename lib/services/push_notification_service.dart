import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final SupabaseClient _client = Supabase.instance.client;

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'comunidad_alertas',
        'Alertas Comunidad Bochil',
        description: 'Notificaciones de reportes y alertas oficiales',
        importance: Importance.high,
      );

  bool _initialized = false;

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint('[Push] Background message: ${message.messageId}');
  }

  Future<void> init({
    Future<void> Function(Map<String, dynamic> data)? onNotificationTap,
  }) async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _initLocalNotifications(onNotificationTap: onNotificationTap);

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[Push] Permisos: ${settings.authorizationStatus.name}');

      await _registrarTokenActual();

      _messaging.onTokenRefresh.listen((token) async {
        await _guardarTokenEnSupabase(token);
      });

      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('[Push] Foreground: ${message.notification?.title}');
        _mostrarNotificacionLocal(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) async {
        if (onNotificationTap != null) {
          await onNotificationTap(message.data);
        }
      });

      final initial = await _messaging.getInitialMessage();
      if (initial != null && onNotificationTap != null) {
        await onNotificationTap(initial.data);
      }
    } catch (e) {
      debugPrint('[Push] Error inicializando push: $e');
    }
  }

  Future<void> _initLocalNotifications({
    Future<void> Function(Map<String, dynamic> data)? onNotificationTap,
  }) async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) async {
        if (onNotificationTap == null) return;
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          await onNotificationTap({});
          return;
        }

        try {
          final map = jsonDecode(payload) as Map<String, dynamic>;
          await onNotificationTap(map);
        } catch (_) {
          await onNotificationTap({});
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
  }

  Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Notificación Comunidad Bochil';
    final body = message.notification?.body ?? 'Tienes una actualización.';

    final payload = jsonEncode(message.data);

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  Future<void> _registrarTokenActual() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _guardarTokenEnSupabase(token);
    } catch (e) {
      debugPrint('[Push] Error obteniendo token: $e');
    }
  }

  Future<void> _guardarTokenEnSupabase(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client.from('device_tokens').upsert(
        {
          'usuario_id': userId,
          'token': token,
          'plataforma': _plataformaActual(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'usuario_id,token',
      );
      debugPrint('[Push] Token guardado/actualizado.');
    } catch (e) {
      debugPrint('[Push] Error guardando token en Supabase: $e');
    }
  }

  Future<void> limpiarTokenActual() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      await _client
          .from('device_tokens')
          .delete()
          .eq('usuario_id', userId)
          .eq('token', token);

      debugPrint('[Push] Token eliminado para logout.');
    } catch (e) {
      debugPrint('[Push] Error eliminando token en logout: $e');
    }
  }

  String _plataformaActual() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'android';
  }
}
