import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/game_screen.dart';
import 'ui/intro_screens.dart';
import 'ui/pixel_scale.dart';
import 'ui/ui_state.dart';

class LuchaTapApp extends ConsumerWidget {
  const LuchaTapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WidgetsApp(
      title: 'Lucha Tap, Tap!',
      color: const Color(0xFF1B1230),
      debugShowCheckedModeBanner: false,
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
      ),
      home: const PixelCanvas(builder: _buildStage),
    );
  }

  static Widget _buildStage(BuildContext context) => const _Stage();
}

/// Splash, then loading, then the game.
class _Stage extends ConsumerWidget {
  const _Stage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(appStageProvider)) {
      AppStage.splash => const SplashScreen(),
      AppStage.loading => const LoadingScreen(),
      AppStage.game => const GameScreen(),
    };
  }
}
