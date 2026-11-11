import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/content_exception.dart';
import 'core/save_codec.dart';
import 'data/content_loader.dart';
import 'services/game_controller.dart';
import 'services/save_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  try {
    final content = await loadContent();
    final store = FileSaveStore(
      directory: await getApplicationDocumentsDirectory(),
      codec: SaveCodec(content: content),
    );
    final loaded = await store.load();
    if (loaded.error != null) {
      // A damaged main save falls back to the backup; report it for debugging.
      debugPrint('Save problem (${loaded.source.name}): ${loaded.error}');
    }
    runApp(ProviderScope(
      overrides: [
        contentProvider.overrideWithValue(content),
        saveStoreProvider.overrideWithValue(store),
        initialSaveProvider.overrideWithValue(loaded.data),
      ],
      child: const LuchaTapApp(),
    ));
  } on ContentException catch (e) {
    // A bad data file must fail loudly: debug builds crash with the message,
    // release builds show a plain error screen instead of a broken game.
    if (kDebugMode) rethrow;
    runApp(_LoadErrorApp(message: e.message));
  }
}

class _LoadErrorApp extends StatelessWidget {
  const _LoadErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: const Color(0xFF1B1230),
      builder: (context, _) => ColoredBox(
        color: const Color(0xFF1B1230),
        child: Center(
          child: Text(
            'No se pudieron cargar los datos del juego.\n$message',
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: const TextStyle(color: Color(0xFFF6F0E4), fontSize: 14),
          ),
        ),
      ),
    );
  }
}
