import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emite `true` cuando hay conexión, `false` cuando no.
final conectividadProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
        (result) => !result.contains(ConnectivityResult.none),
      );
});
