import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Credenciales de Supabase.
/// TODO: Reemplaza con tus valores reales desde el dashboard de Supabase.
const String supabaseUrl = 'https://goeeptzfmaunnlgaldla.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdvZWVwdHpmbWF1bm5sZ2FsZGxhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMyMTI3MzMsImV4cCI6MjA4ODc4ODczM30.75YpSVMm8AMRLWw0x1kpacXKhX0GaGT4Z2pD5hxlXyU';

/// Coordenadas de Bochil, Chiapas (centro del municipio).
final LatLng bochilCenter = LatLng(17.0386, -92.8883);

/// Colores institucionales SAPAM.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1565C0); // Azul SAPAM
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color accent = Color(0xFF26C6DA); // Cyan agua
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFD32F2F);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
}

/// Categorías de los reportes (mapea al enum de Supabase).
enum CategoriaReporte {
  fuga('Fuga'),
  sinAgua('Sin Agua'),
  bajaPresion('Baja Presion'),
  contaminacion('Contaminacion'),
  infraestructura('Infraestructura');

  final String value;
  const CategoriaReporte(this.value);

  static CategoriaReporte fromString(String s) {
    return CategoriaReporte.values.firstWhere((e) => e.value == s);
  }
}

/// Estados de un reporte.
enum EstadoReporte {
  pendiente('Pendiente'),
  enRevision('En Revision'),
  enProgreso('En Progreso'),
  resuelto('Resuelto');

  final String value;
  const EstadoReporte(this.value);

  static EstadoReporte fromString(String s) {
    return EstadoReporte.values.firstWhere((e) => e.value == s);
  }
}
