import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/welcome_screen.dart';
import '../screens/scanner_screen.dart';
import '../screens/contract_verify_screen.dart';
import '../screens/phone_input_screen.dart';
import '../screens/otp_verify_screen.dart';
import '../screens/recuperacion_screen.dart';
import '../screens/main_scaffold.dart';
import '../screens/location_picker_screen.dart';
import '../screens/report_form_screen.dart';
import '../screens/reporte_detalle_screen.dart';
import '../screens/reporte_detalle_loader_screen.dart';
import '../screens/crear_tema_screen.dart';
import '../screens/tema_detalle_screen.dart';
import '../screens/notificaciones_screen.dart';
import '../models/reporte.dart';
import '../models/tema_foro.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final supabase = Supabase.instance.client;

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loggedIn = supabase.auth.currentUser != null;
      final loc = state.matchedLocation;

      // Rutas que NO requieren autenticación
      final isPublicRoute = loc == '/welcome' ||
          loc == '/scanner' ||
          loc == '/contract-verify' ||
          loc == '/phone-input' ||
          loc == '/otp-verify' ||
          loc == '/recuperacion' ||
          loc == '/notificaciones';

      // Si no está logueado y quiere entrar a una ruta protegida → welcome
      if (!loggedIn && !isPublicRoute) {
        return '/welcome';
      }

      // Si está logueado y está en welcome → ir al home
      if (loggedIn && loc == '/welcome') {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MainScaffold(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/scanner',
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/contract-verify',
        builder: (context, state) => const ContractVerifyScreen(),
      ),
      GoRoute(
        path: '/phone-input',
        builder: (context, state) => const PhoneInputScreen(),
      ),
      GoRoute(
        path: '/otp-verify',
        builder: (context, state) => const OtpVerifyScreen(),
      ),
      GoRoute(
        path: '/recuperacion',
        builder: (context, state) => const RecuperacionScreen(),
      ),
      GoRoute(
        path: '/notificaciones',
        builder: (context, state) => const NotificacionesScreen(),
      ),
      GoRoute(
        path: '/location-picker',
        builder: (context, state) => const LocationPickerScreen(),
      ),
      GoRoute(
        path: '/report-form',
        builder: (context, state) {
          final extra = state.extra;

          if (extra is Map<String, dynamic>) {
            return ReportFormScreen(
              ubicacion: extra['ubicacion'] as LatLng,
              direccionLegible: extra['direccionLegible'] as String?,
              coloniaSeleccionada: extra['colonia'] as String?,
            );
          }

          return ReportFormScreen(ubicacion: extra as LatLng);
        },
      ),
      GoRoute(
        path: '/reporte-detalle',
        builder: (context, state) {
          final reporte = state.extra as Reporte;
          return ReporteDetalleScreen(reporte: reporte);
        },
      ),
      GoRoute(
        path: '/reporte-detalle-id/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReporteDetalleLoaderScreen(reporteId: id);
        },
      ),
      GoRoute(
        path: '/foro/crear',
        builder: (context, state) => const CrearTemaScreen(),
      ),
      GoRoute(
        path: '/foro/detalle',
        builder: (context, state) {
          final tema = state.extra as TemaForo;
          return TemaDetalleScreen(tema: tema);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Ruta no encontrada: ${state.error}')),
    ),
  );
});
