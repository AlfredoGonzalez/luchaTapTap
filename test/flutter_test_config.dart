import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Every test runs as if the phone were in Spanish (the game follows the
/// phone's language); tests about English choose it explicitly.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.localeTestValue =
      const Locale('es', 'MX');
  await testMain();
}
