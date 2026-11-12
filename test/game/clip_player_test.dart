import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/game/clip_player.dart';

import '../test_content.dart';

void main() {
  final anim = loadTestContent().balance.animations;

  test('the sheet layout comes from the data: one row per clip', () {
    expect(anim.order, ['idle', 'attack', 'hit', 'defeated', 'victory']);
    expect(anim.columns, anim.clips.values.map((c) => c.frames).reduce((a, b) => a > b ? a : b));
    expect(anim.rowOf('hit'), 2);
  });

  test('idle loops at its own speed', () {
    final p = ClipPlayer(anim);
    final idle = anim.clips['idle']!;
    expect(p.frame, 0);
    p.update(1 / idle.fps + 1e-6);
    expect(p.frame, 1);
    p.update(idle.seconds); // a whole loop later
    expect(p.frame, 1);
  });

  test('attack plays once and returns to idle', () {
    final p = ClipPlayer(anim)..play('attack');
    final attack = anim.clips['attack']!;
    p.update(attack.seconds - 0.001);
    expect(p.clip, 'attack');
    expect(p.frame, attack.frames - 1);
    p.update(0.01);
    expect(p.clip, 'idle');
    expect(p.frame, 0);
  });

  test('defeated holds its last frame', () {
    final p = ClipPlayer(anim)..play('defeated', then: null);
    p.update(10);
    expect(p.clip, 'defeated');
    expect(p.frame, anim.clips['defeated']!.frames - 1);
    expect(p.finished, isTrue);
  });

  test('playing a clip again restarts it', () {
    final p = ClipPlayer(anim)..play('attack');
    p.update(0.2);
    p.play('attack');
    expect(p.frame, 0);
  });
}
