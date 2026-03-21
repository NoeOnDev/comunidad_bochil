import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Coordenadas de Bochil, Chiapas (centro del municipio).
final LatLng bochilCenter = LatLng(16.995714, -92.893498);

/// Paleta institucional de Comunidad Bochil.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1565C0); // Azul principal
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
