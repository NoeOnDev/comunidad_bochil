import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../models/tema_foro.dart';
import '../providers/providers.dart';
import '../widgets/offline_state_widget.dart';
import '../widgets/tema_card.dart';
import '../providers/connectivity_provider.dart';

class ForoScreen extends ConsumerStatefulWidget {
  const ForoScreen({super.key});

  @override
  ConsumerState<ForoScreen> createState() => _ForoScreenState();
}

class _ForoScreenState extends ConsumerState<ForoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refrescar() {
    ref.invalidate(temasForoProvider);
  }

  List<TemaForo> _filtrarPorCategoria(
    List<TemaForo> todos,
    CategoriaTema? categoria,
  ) {
    if (categoria == null) return todos;
    return todos.where((t) => t.categoria == categoria).toList();
  }

  @override
  Widget build(BuildContext context) {
    final temasAsync = ref.watch(temasForoProvider);
    final conectado = ref.watch(conectividadProvider).valueOrNull ?? true;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 16,
        title: const Text('Foro Comunitario'),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: () => context.push('/notificaciones'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(onPressed: _refrescar, icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: 'Crear tema',
            onPressed: () async {
              await context.push('/foro/crear');
              ref.invalidate(temasForoProvider);
            },
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          padding: EdgeInsets.zero,
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Propuestas'),
            Tab(text: 'Preguntas'),
            Tab(text: 'Discusiones'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!conectado) const OfflineBanner(),
          Expanded(
            child: temasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => OfflineStateWidget(onReintentar: _refrescar),
              data: (temas) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _ListaTemas(temas: _filtrarPorCategoria(temas, null)),
                    _ListaTemas(
                      temas: _filtrarPorCategoria(temas, CategoriaTema.propuesta),
                    ),
                    _ListaTemas(
                      temas: _filtrarPorCategoria(temas, CategoriaTema.pregunta),
                    ),
                    _ListaTemas(
                      temas: _filtrarPorCategoria(temas, CategoriaTema.discusion),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaTemas extends StatelessWidget {
  final List<TemaForo> temas;

  const _ListaTemas({required this.temas});

  @override
  Widget build(BuildContext context) {
    if (temas.isEmpty) {
      return const Center(
        child: Text(
          'Aún no hay temas en esta categoría.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: temas.length,
      separatorBuilder: (_, _) => Container(height: 8, color: Colors.grey.shade100),
      itemBuilder: (_, index) => TemaCard(tema: temas[index]),
    );
  }
}
