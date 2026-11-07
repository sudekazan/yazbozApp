import 'package:go_router/go_router.dart';

import '../../features/game_over/game_over_screen.dart';
import '../../features/game_setup/game_select_screen.dart';
import '../../features/game_setup/game_setup_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/scoreboard/scoreboard_screen.dart';
import '../../features/settings/settings_screen.dart';
import 'not_found_screen.dart';

/// Uygulamadaki adresler. Ekranlar adres yazmak yerine bunları kullanır.
abstract final class AppRoutes {
  static const String home = '/';
  static const String newGame = '/new';
  static const String settings = '/settings';

  static String setup(String template) => '/new/$template';
  static String game(int id) => '/game/$id';
  static String gameOver(int id) => '/game/$id/result';
}

/// Uygulamanın yönlendiricisi. Alt adresler ana sayfanın altına dizildiği için
/// geri tuşu her zaman bir üst ekrana döner.
GoRouter createAppRouter({String initialLocation = AppRoutes.home}) {
  return GoRouter(
    initialLocation: initialLocation,
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const GameSelectScreen(),
            routes: [
              GoRoute(
                path: ':template',
                builder: (context, state) => GameSetupScreen(
                  template: state.pathParameters['template']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'game/:id',
            builder: (context, state) {
              final id = _parseId(state);
              return id == null
                  ? const NotFoundScreen()
                  : ScoreboardScreen(gameId: id);
            },
            routes: [
              GoRoute(
                path: 'result',
                builder: (context, state) {
                  final id = _parseId(state);
                  return id == null
                      ? const NotFoundScreen()
                      : GameOverScreen(gameId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
}

/// Adresteki oyun numarasını okur; sayı değilse ya da pozitif değilse `null`.
int? _parseId(GoRouterState state) {
  final id = int.tryParse(state.pathParameters['id'] ?? '');
  return id != null && id > 0 ? id : null;
}
