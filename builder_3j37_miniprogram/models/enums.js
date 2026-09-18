// models/enums.js - 枚举定义
const Position = { PG: 0, SG: 1, SF: 2, PF: 3, C: 4 };
const POSITION_LABELS = ['PG', 'SG', 'SF', 'PF', 'C'];
const POSITION_FULL_NAMES = ['Point Guard', 'Shooting Guard', 'Small Forward', 'Power Forward', 'Center'];

const Discipline = { finishing: 1, shooting: 2, playmaking: 3, defense: 4, rebounding: 5, physicals: 6 };
const DISCIPLINE_LABELS = ['', 'finishing', 'shooting', 'playmaking', 'defense', 'rebounding', 'physicals'];
const DISCIPLINE_DISPLAY = ['', 'Finishing', 'Shooting', 'Playmaking', 'Defense', 'Rebounding', 'Physicals'];
const DISCIPLINE_COLORS = ['', '#3764B3', '#61AF57', '#E29754', '#DE574B', '#9785EA', '#A27D32'];

const BadgeTier = { bronze: 1, silver: 2, gold: 3, hallOfFame: 4, legend: 5 };
const BADGE_TIER_LABELS = ['', 'Bronze', 'Silver', 'Gold', 'Hall of Fame', 'Legend'];
const BADGE_TIER_KEYS = ['', 'bronze', 'silver', 'gold', 'hall_of_fame', 'legend'];
const BADGE_TIER_COLORS = ['', '#CD7F32', '#C0C0C0', '#E0AE40', '#9B59B6', '#FF6B6B'];

const NATIVE_NAMES = [
  'ShotClose','DrivingLayup','DrivingDunk','StandingDunk','PostControl',
  'ShotMidrange','ShotThree','ShotFreeThrow','PassAccuracy','BallControl',
  'SpeedWithBall','InteriorDefense','PerimeterDefense','Steal','Block',
  'ReboundOffense','ReboundDefense','Speed','Agility','Strength','Vertical',
];

const ATTRIBUTE_KEYS = [
  'close_shot','driving_layup','driving_dunk','standing_dunk','post_control',
  'mid_range','three_point','free_throw','pass_accuracy','ball_handle',
  'speed_with_ball','interior_defense','perimeter_defense','steal','block',
  'offensive_rebound','defensive_rebound','speed','agility','strength','vertical'
];

const DISCIPLINE_ATTRS = {
  1: [0,1,2,3,4],
  2: [5,6,7],
  3: [8,9,10],
  4: [11,12,13,14],
  5: [15,16],
  6: [17,18,19,20],
};

module.exports = {
  Position, POSITION_LABELS, POSITION_FULL_NAMES,
  Discipline, DISCIPLINE_LABELS, DISCIPLINE_DISPLAY, DISCIPLINE_COLORS,
  BadgeTier, BADGE_TIER_LABELS, BADGE_TIER_KEYS, BADGE_TIER_COLORS,
  NATIVE_NAMES, ATTRIBUTE_KEYS, DISCIPLINE_ATTRS,
};
