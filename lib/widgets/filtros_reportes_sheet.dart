import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/filtros_reporte.dart';

Future<FiltrosReporte?> mostrarFiltrosReportesSheet({
  required BuildContext context,
  required FiltrosReporte inicial,
  required List<String> coloniasDisponibles,
}) {
  return showModalBottomSheet<FiltrosReporte>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FiltrosReportesSheet(
      inicial: inicial,
      coloniasDisponibles: coloniasDisponibles,
    ),
  );
}

class _FiltrosReportesSheet extends StatefulWidget {
  final FiltrosReporte inicial;
  final List<String> coloniasDisponibles;

  const _FiltrosReportesSheet({
    required this.inicial,
    required this.coloniasDisponibles,
  });

  @override
  State<_FiltrosReportesSheet> createState() => _FiltrosReportesSheetState();
}

class _FiltrosReportesSheetState extends State<_FiltrosReportesSheet> {
  late CategoriaReporte? _categoria;
  late EstadoReporte? _estado;
  late String? _colonia;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  @override
  void initState() {
    super.initState();
    _categoria = widget.inicial.categoria;
    _estado = widget.inicial.estado;
    _colonia = widget.inicial.colonia;
    _fechaDesde = widget.inicial.fechaDesde;
    _fechaHasta = widget.inicial.fechaHasta;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Filtrar reportes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<CategoriaReporte?>(
              initialValue: _categoria,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                const DropdownMenuItem<CategoriaReporte?>(
                  value: null,
                  child: Text('Todas'),
                ),
                ...CategoriaReporte.values.map(
                  (cat) => DropdownMenuItem<CategoriaReporte?>(
                    value: cat,
                    child: Text(cat.value),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _categoria = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EstadoReporte?>(
              initialValue: _estado,
              decoration: const InputDecoration(
                labelText: 'Estado',
                prefixIcon: Icon(Icons.rule_folder_outlined),
              ),
              items: [
                const DropdownMenuItem<EstadoReporte?>(
                  value: null,
                  child: Text('Todos'),
                ),
                ...EstadoReporte.values.map(
                  (est) => DropdownMenuItem<EstadoReporte?>(
                    value: est,
                    child: Text(est.value),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _estado = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _colonia,
              decoration: const InputDecoration(
                labelText: 'Colonia',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todas'),
                ),
                ...widget.coloniasDisponibles.map(
                  (col) => DropdownMenuItem<String?>(
                    value: col,
                    child: Text(col),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _colonia = value),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _seleccionarRangoFechas,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(_textoRangoFechas()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _limpiarFiltros,
                    child: const Text('Limpiar filtros'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _aplicarFiltros,
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarRangoFechas() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _fechaDesde != null && _fechaHasta != null
          ? DateTimeRange(start: _fechaDesde!, end: _fechaHasta!)
          : null,
      helpText: 'Selecciona rango de fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );

    if (picked != null) {
      setState(() {
        _fechaDesde = picked.start;
        _fechaHasta = picked.end;
      });
    }
  }

  String _textoRangoFechas() {
    if (_fechaDesde == null || _fechaHasta == null) {
      return 'Seleccionar rango de fechas';
    }
    return '${_fechaDesde!.day}/${_fechaDesde!.month}/${_fechaDesde!.year} - '
        '${_fechaHasta!.day}/${_fechaHasta!.month}/${_fechaHasta!.year}';
  }

  void _limpiarFiltros() {
    Navigator.pop(context, const FiltrosReporte());
  }

  void _aplicarFiltros() {
    Navigator.pop(
      context,
      FiltrosReporte(
        categoria: _categoria,
        estado: _estado,
        colonia: _colonia,
        fechaDesde: _fechaDesde,
        fechaHasta: _fechaHasta,
      ),
    );
  }
}
