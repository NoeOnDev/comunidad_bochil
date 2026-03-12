import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/perfil_usuario.dart';
import '../models/reporte.dart';

/// Servicio de caché local usando SharedPreferences.
/// Guarda copias de perfil y reportes para lectura offline.
class CacheService {
  static const _keyPerfil = 'cached_profile';
  static const _keyReportes = 'cached_reports';
  static const _keyReportesEnriquecidos = 'cached_reports_enriched';

  // ─── Perfil ────────────────────────────────────────────────────────────────

  static Future<void> guardarPerfil(PerfilUsuario perfil) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPerfil, jsonEncode(perfil.toJson()));
  }

  static Future<PerfilUsuario?> obtenerPerfilCacheado() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPerfil);
    if (raw == null) return null;
    return PerfilUsuario.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  // ─── Reportes (mapa) ──────────────────────────────────────────────────────

  static Future<void> guardarReportes(List<Reporte> reportes) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = reportes.map((r) => r.toJsonCompleto()).toList();
    await prefs.setString(_keyReportes, jsonEncode(lista));
  }

  static Future<List<Reporte>?> obtenerReportesCacheados() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyReportes);
    if (raw == null) return null;
    final lista = jsonDecode(raw) as List;
    return lista
        .map((j) => Reporte.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ─── Reportes enriquecidos (feed) ─────────────────────────────────────────

  static Future<void> guardarReportesEnriquecidos(
    List<Reporte> reportes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = reportes.map((r) => r.toJsonCompleto()).toList();
    await prefs.setString(_keyReportesEnriquecidos, jsonEncode(lista));
  }

  static Future<List<Reporte>?> obtenerReportesEnriquecidosCacheados() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyReportesEnriquecidos);
    if (raw == null) return null;
    final lista = jsonDecode(raw) as List;
    return lista
        .map((j) => Reporte.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
