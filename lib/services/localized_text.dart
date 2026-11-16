import '../data/content_models.dart';
import '../data/goals_models.dart';
import 'strings.dart';

/// Translated names and descriptions of data entries. Character names
/// (opponents, masks, trainers) stay in Spanish in every language.
extension LocalizedText on Strings {
  String upgradeName(UpgradeDef u) => data('upgrades', u.id, 'name', u.name);
  String upgradeDescription(UpgradeDef u) =>
      data('upgrades', u.id, 'description', u.description);

  String trainerDescription(TrainerDef t) =>
      data('trainers', t.id, 'description', t.description);

  String skillName(SkillDef s) => data('skills', s.id, 'name', s.name);
  String skillText(SkillDef s) =>
      data('skills', s.id, 'description', s.description);

  String talentName(TalentDef t) => data('talents', t.id, 'name', t.name);
  String branchName(TalentBranchDef b) => data('branches', b.id, 'name', b.name);

  String leagueName(LeagueDef l) => data('leagues', l.id, 'name', l.name);

  String achievementName(AchievementDef a) =>
      data('achievements', a.id, 'name', a.name);

  String shopName(ShopItemDef i) => data('shop', i.id, 'name', i.name);
  String shopDetail(ShopItemDef i) => data('shop', i.id, 'detail', i.detail);

  String eventName(EventDef e) => data('events', e.id, 'name', e.name);
  String eventText(EventDef e) => data('events', e.id, 'text', e.text);

  /// Credits have no ids: the Spanish text is the key.
  String credit(String text) => data('credits', text, 'text', text);
}
