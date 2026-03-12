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
import '../screens/main_scaffold.dart';
import '../screens/location_picker_screen.dart';
import '../screens/report_form_screen.dart';
import '../screens/reporte_detalle_screen.dart';
import '../models/reporte.dart';

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
          loc == '/otp-verify';

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
        path: '/location-picker',
        builder: (context, state) => const LocationPickerScreen(),
      ),
      GoRoute(
        path: '/report-form',
        builder: (context, state) {
          final ubicacion = state.extra as LatLng;
          return ReportFormScreen(ubicacion: ubicacion);
        },
      ),
      GoRoute(
        path: '/reporte-detalle',
        builder: (context, state) {
          final reporte = state.extra as Reporte;
          return ReporteDetalleScreen(reporte: reporte);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Ruta no encontrada: ${state.error}')),
    ),
  );
});
