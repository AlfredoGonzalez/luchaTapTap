import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/game_screen.dart';
import 'ui/pixel_scale.dart';

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
        pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      ),
      home: const PixelCanvas(builder: _buildGame),
    );
  }

  static Widget _buildGame(BuildContext context) => const GameScreen();
}
