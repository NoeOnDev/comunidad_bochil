import '../core/constants.dart';
import 'reporte.dart';

class FiltrosReporte {
  final CategoriaReporte? categoria;
  final EstadoReporte? estado;
  final String? colonia;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;

  const FiltrosReporte({
    this.categoria,
    this.estado,
    this.colonia,
    this.fechaDesde,
    this.fechaHasta,
  });

  bool get tieneFiltrosActivos {
    return categoria != null ||
        estado != null ||
        (colonia != null && colonia!.trim().isNotEmpty) ||
        fechaDesde != null ||
        fechaHasta != null;
  }

  FiltrosReporte limpiar() => const FiltrosReporte();

  FiltrosReporte copyWith({
    CategoriaReporte? categoria,
    EstadoReporte? estado,
    String? colonia,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    bool limpiarCategoria = false,
    bool limpiarEstado = false,
    bool limpiarColonia = false,
    bool limpiarFechaDesde = false,
    bool limpiarFechaHasta = false,
  }) {
    return FiltrosReporte(
      categoria: limpiarCategoria ? null : (categoria ?? this.categoria),
      estado: limpiarEstado ? null : (estado ?? this.estado),
      colonia: limpiarColonia ? null : (colonia ?? this.colonia),
      fechaDesde: limpiarFechaDesde ? null : (fechaDesde ?? this.fechaDesde),
      fechaHasta: limpiarFechaHasta ? null : (fechaHasta ?? this.fechaHasta),
    );
  }

  List<Reporte> aplicar(List<Reporte> reportes) {
    return reportes.where((reporte) {
      if (categoria != null && reporte.categoria != categoria) return false;
      if (estado != null && reporte.estado != estado) return false;

      if (colonia != null && colonia!.trim().isNotEmpty) {
        if (reporte.colonia.trim().toLowerCase() != colonia!.trim().toLowerCase()) {
          return false;
        }
      }

      if (fechaDesde != null) {
        final desde = DateTime(fechaDesde!.year, fechaDesde!.month, fechaDesde!.day);
        if (reporte.createdAt.isBefore(desde)) return false;
      }

      if (fechaHasta != null) {
        final hasta = DateTime(
          fechaHasta!.year,
          fechaHasta!.month,
          fechaHasta!.day,
          23,
          59,
          59,
          999,
        );
        if (reporte.createdAt.isAfter(hasta)) return false;
      }

      return true;
    }).toList();
  }
}
