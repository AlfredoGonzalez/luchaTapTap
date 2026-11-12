// Runs the balance simulation under different player assumptions, to check
// that the pacing does not depend on one exact kind of player:
//
//   dart run tool/balance_sensitivity.dart [hours] [data-folder]
import 'dart:convert';
import 'dart:io';

import 'package:lucha_tap_tap/data/content_bundle.dart';
import 'package:lucha_tap_tap/dev/balance_sim.dart';

String _m(double? v) => v == null ? '   -  ' : v.toStringAsFixed(0).padLeft(5);

void main(List<String> args) {
  final hours = args.isNotEmpty ? double.parse(args[0]) : 3;
  final folder = args.length > 1 ? args[1] : 'assets/data';
  final content = ContentBundle.parse({
    for (final name in ContentFiles.all)
      name: jsonDecode(File('$folder/$name').readAsStringSync()) as Map<String, dynamic>,
  });
  final length = Duration(minutes: (hours * 60).round());

  BotProfile p(String name, {double taps = 4, double finisher = 0.8, double gesture = 2.5, double stall = 5, double lucky = 0.6, double? session, double? every}) =>
      BotProfile(
        name: name,
        tapsPerSecond: taps,
        actEverySeconds: 2,
        finisherSuccess: finisher,
        gestureSeconds: gesture,
        luckyCatch: lucky,
        stallMinutesBeforePrestige: stall,
        sessionMinutes: session,
        sessionEveryMinutes: every,
      );

  final cases = [
    p('activo (referencia)'),
    p('toca 2/s', taps: 2),
    p('toca 6/s', taps: 6),
    p('gesto 40% de acierto', finisher: 0.4),
    p('nunca hace el gesto', finisher: 0, gesture: 0),
    p('no atrapa suerte', lucky: 0),
    p('prestigia tras 2 min', stall: 2),
    p('prestigia tras 10 min', stall: 10),
    p('casual 5 min cada 30', taps: 3, session: 5, every: 30),
    p('casual 10 min cada 2 h', taps: 3, session: 10, every: 120),
  ];
  stdout.writeln('${'jugador'.padRight(26)} disp.  1er   2do   3er  pelea20 pelea30 pelea50 mejor@1h mejor@3h');
  for (final c in cases) {
    final r = simulate(content, c, length: length);
    int bestAt(double m) => r.snapshots.lastWhere((s) => s.minute <= m + 0.5, orElse: () => r.snapshots.first).bestFight;
    final pm = r.prestigeMinutes;
    stdout.writeln('${c.name.padRight(26)} ${_m(r.firstMinute('prestigio disponible'))} ${_m(pm.isNotEmpty ? pm[0] : null)} '
        '${_m(pm.length > 1 ? pm[1] : null)} ${_m(pm.length > 2 ? pm[2] : null)} '
        '${_m(r.firstMinute('pelea 20')).padLeft(7)} ${_m(r.firstMinute('pelea 30')).padLeft(7)} ${_m(r.firstMinute('pelea 50')).padLeft(7)} '
        '${bestAt(60).toString().padLeft(8)} ${r.snapshots.last.bestFight.toString().padLeft(8)}');
  }
}
