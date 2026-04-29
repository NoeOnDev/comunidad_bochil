import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../models/perfil_usuario.dart';
import '../providers/providers.dart';
import '../services/push_notification_service.dart';
import '../widgets/offline_state_widget.dart';
import 'mis_reportes_asignados_screen.dart';
import 'home_screen.dart';
import 'feed_comunitario_screen.dart';
import 'foro_screen.dart';
import 'perfil_screen.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  List<Widget> _screens({required bool esTecnico}) {
    if (esTecnico) {
      return const [MisReportesAsignadosScreen(), PerfilScreen()];
    }

    return const [
      HomeScreen(),
      FeedComunitarioScreen(),
      ForoScreen(),
      PerfilScreen(),
    ];
  }

  List<NavigationDestination> _destinations({required bool esTecnico}) {
    if (esTecnico) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment, color: AppColors.primary),
          label: 'Asignados',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person, color: AppColors.primary),
          label: 'Perfil',
        ),
      ];
    }

    return const [
      NavigationDestination(
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map, color: AppColors.primary),
        label: 'Inicio',
      ),
      NavigationDestination(
        icon: Icon(Icons.forum_outlined),
        selectedIcon: Icon(Icons.forum, color: AppColors.primary),
        label: 'Comunidad',
      ),
      NavigationDestination(
        icon: Icon(Icons.groups_outlined),
        selectedIcon: Icon(Icons.groups, color: AppColors.primary),
        label: 'Foro',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person, color: AppColors.primary),
        label: 'Perfil',
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciarPush();
    _validarSesionActiva();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _validarSesionActiva();
    }
  }

  Future<void> _iniciarPush() async {
    await PushNotificationService.instance.init(
      onNotificationTap: (data) async {
        if (!mounted) return;
        final reporteIdRaw = data['reporte_id']?.toString().trim();
        if (reporteIdRaw != null && reporteIdRaw.isNotEmpty) {
          context.push('/reporte-detalle-id/$reporteIdRaw');
          return;
        }
        // Fallback: abrir centro de notificaciones.
        context.push('/notificaciones');
      },
    );
  }

  Future<void> _validarSesionActiva() async {
    final authRepo = ref.read(authRepositoryProvider);
    final valida = await authRepo.sesionSigueValida();

    if (valida) {
      ref.invalidate(authUserServerProvider);
      ref.invalidate(perfilUsuarioProvider);
      return;
    }

    if (!mounted) return;

    await authRepo.cerrarSesion();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tu sesión expiró o la cuenta ya no existe. Inicia sesión nuevamente.',
        ),
      ),
    );
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final perfilAsync = ref.watch(perfilUsuarioProvider);

    return perfilAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: OfflineStateWidget(
          onReintentar: () => ref.invalidate(perfilUsuarioProvider),
        ),
      ),
      data: (perfil) {
        final esTecnico = perfil?.esTecnico ?? false;
        final screens = _screens(esTecnico: esTecnico);
        final destinations = _destinations(esTecnico: esTecnico);
        final selectedIndex = _currentIndex >= screens.length
            ? 0
            : _currentIndex;

        return Scaffold(
          body: IndexedStack(index: selectedIndex, children: screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primary.withValues(alpha: 0.15),
            destinations: destinations,
          ),
        );
      },
    );
  }
}
