/// Position enum matching dataset codes 0-4
enum Position { pg, sg, sf, pf, c }

extension PositionX on Position {
  int get code => index;
  String get label => ['PG', 'SG', 'SF', 'PF', 'C'][index];
  String get fullName => ['Point Guard','Shooting Guard','Small Forward','Power Forward','Center'][index];

  static Position fromCode(int code) => Position.values[code];
}

/// Discipline enum matching dataset codes 1-6
enum Discipline { finishing, shooting, playmaking, defense, rebounding, physicals }

extension DisciplineX on Discipline {
  int get code => index + 1;
  String get label => name;
  String get displayName => name[0].toUpperCase() + name.substring(1);

  static Discipline fromCode(int code) => Discipline.values[code - 1];
  static Discipline fromOrder(int order) => Discipline.values[order];
}

/// Badge tier
enum BadgeTier { bronze, silver, gold, hallOfFame, legend }

extension BadgeTierX on BadgeTier {
  int get code => index + 1;
  String get label => ['Bronze', 'Silver', 'Gold', 'Hall of Fame', 'Legend'][index];
  String get key => ['bronze', 'silver', 'gold', 'hall_of_fame', 'legend'][index];

  static BadgeTier fromCode(int code) => BadgeTier.values[code - 1];
  static BadgeTier fromKey(String key) {
    switch (key) {
      case 'bronze': return BadgeTier.bronze;
      case 'silver': return BadgeTier.silver;
      case 'gold': return BadgeTier.gold;
      case 'hall_of_fame': return BadgeTier.hallOfFame;
      case 'legend': return BadgeTier.legend;
      default: return BadgeTier.bronze;
    }
  }
}
