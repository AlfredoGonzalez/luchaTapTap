// Balance report: plays the game with simulated players and prints when each
// milestone is reached. Run with:
//
//   dart run tool/balance_report.dart [hours] [data-folder] [profiles]
//
// The folder defaults to assets/data; profiles is a comma list of
// activo,casual,pasivo (default: all).
import 'dart:convert';
import 'dart:io';

import 'package:lucha_tap_tap/core/number_format.dart';
import 'package:lucha_tap_tap/data/content_bundle.dart';
import 'package:lucha_tap_tap/dev/balance_sim.dart';

String _min(double? m) => m == null ? '   -   ' : '${m.toStringAsFixed(1).padLeft(6)} ';

void main(List<String> args) {
  final hours = args.isNotEmpty ? double.parse(args[0]) : 3;
  final folder = args.length > 1 ? args[1] : 'assets/data';
  final files = {
    for (final name in ContentFiles.all)
      name: jsonDecode(File('$folder/$name').readAsStringSync()) as Map<String, dynamic>,
  };
  final content = ContentBundle.parse(files);
  final wanted = args.length > 2 ? args[2].split(',') : const ['activo', 'casual', 'pasivo'];
  final length = Duration(minutes: (hours * 60).round());

  // BOT_LUCKY=0 plays as someone who never catches the floating belt.
  final lucky = double.tryParse(Platform.environment['BOT_LUCKY'] ?? '');
  for (var profile in [BotProfile.active, BotProfile.casual, BotProfile.idle]) {
    if (!wanted.contains(profile.name)) continue;
    if (lucky != null) profile = profile.withLuckyCatch(lucky);
    final r = simulate(content, profile, length: length);
    stdout.writeln('\n=== Jugador ${profile.name} (${profile.tapsPerSecond} toques/s) · ${hours}h ===');
    stdout.writeln('Prestigio disponible: ${_min(r.firstMinute('prestigio disponible'))}min   '
        'primer prestigio: ${_min(r.prestigeMinutes.isNotEmpty ? r.prestigeMinutes[0] : null)}min   '
        'segundo: ${_min(r.prestigeMinutes.length > 1 ? r.prestigeMinutes[1] : null)}min   '
        'tercero: ${_min(r.prestigeMinutes.length > 2 ? r.prestigeMinutes[2] : null)}min');
    stdout.writeln('Hitos (min): '
        '${[for (final m in [5, 9, 11, 15, 20, 30, 40, 50]) 'pelea $m: ${_min(r.firstMinute('pelea $m'))}'].join(' | ')}');
    stdout.writeln('   min  pelea  mejor  prest.  cinturones     dps/s      toque');
    for (final s in r.snapshots) {
      stdout.writeln('${s.minute.toStringAsFixed(0).padLeft(6)} ${s.fight.toString().padLeft(6)} '
          '${s.bestFight.toString().padLeft(6)} ${s.prestiges.toString().padLeft(7)} '
          '${s.belts.toStringAsFixed(0).padLeft(11)} ${formatBig(s.dps).padLeft(9)} ${formatBig(s.tap).padLeft(10)}');
    }
    if (Platform.environment['EARLY'] != null) {
      stdout.writeln('Primeras compras:');
      for (final l in r.buyLog.take(30)) {
        stdout.writeln('   $l');
      }
    }
    final last = r.snapshots.last;
    int bestAt(double minute) => r.snapshots.lastWhere((x) => x.minute <= minute + 0.5, orElse: () => r.snapshots.first).bestFight;
    stdout.writeln('SUMMARY ${profile.name} available=${r.firstMinute('prestigio disponible')?.toStringAsFixed(1)} '
        'prestiges=${r.prestigeMinutes.map((m) => m.toStringAsFixed(1)).join(',')} '
        'best=${last.bestFight} best60=${bestAt(60)} best120=${bestAt(120)} fight20=${r.firstMinute('pelea 20')?.toStringAsFixed(1)} '
        'fight30=${r.firstMinute('pelea 30')?.toStringAsFixed(1)} fight50=${r.firstMinute('pelea 50')?.toStringAsFixed(1)} '
        'firstBuy=${r.buyMinutes.isEmpty ? null : r.buyMinutes.first.toStringAsFixed(2)} '
        'trainer1=${r.firstTrainerMinute?.toStringAsFixed(2)} skill1=${r.firstSkillMinute?.toStringAsFixed(2)} fight5=${r.firstMinute('pelea 5')?.toStringAsFixed(2)} buys10=${r.buysWithin(10)} buys30=${r.buysWithin(30)}');
  }
}