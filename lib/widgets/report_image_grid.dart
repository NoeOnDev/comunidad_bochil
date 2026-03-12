import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Grid de imágenes estilo Facebook para reportes.
/// Cambia dinámicamente según la cantidad de fotos (1, 2 o 3).
class ReportImageGrid extends StatelessWidget {
  final List<String> fotosUrls;
  final double height;
  final double gutter;
  final BorderRadius borderRadius;

  const ReportImageGrid({
    super.key,
    required this.fotosUrls,
    this.height = 260,
    this.gutter = 2,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  bool _esRutaLocal(String url) => !url.startsWith('http');

  Widget _buildImagen(String url, {BoxFit fit = BoxFit.cover}) {
    if (_esRutaLocal(url)) {
      final archivo = File(url);
      if (archivo.existsSync()) {
        return Image.file(archivo, fit: fit, width: double.infinity, height: double.infinity);
      }
      return _errorWidget();
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, _) => Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, _, _) => _errorWidget(),
    );
  }

  Widget _errorWidget() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (fotosUrls.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: switch (fotosUrls.length) {
          1 => _buildImagen(fotosUrls[0]),
          2 => _buildDosImagenes(),
          _ => _buildTresImagenes(),
        },
      ),
    );
  }

  Widget _buildDosImagenes() {
    return Row(
      children: [
        Expanded(child: _buildImagen(fotosUrls[0])),
        SizedBox(width: gutter),
        Expanded(child: _buildImagen(fotosUrls[1])),
      ],
    );
  }

  Widget _buildTresImagenes() {
    return Row(
      children: [
        Expanded(child: _buildImagen(fotosUrls[0])),
        SizedBox(width: gutter),
        Expanded(
          child: Column(
            children: [
              Expanded(child: _buildImagen(fotosUrls[1])),
              SizedBox(height: gutter),
              Expanded(child: _buildImagen(fotosUrls[2])),
            ],
          ),
        ),
      ],
    );
  }
}
