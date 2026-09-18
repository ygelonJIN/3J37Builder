const { TuningParser } = require('./tuning-parser');

class DatasetLoader {
  constructor() {
    this.definitions = null;
    this.tierRequirements = null;
    this.tokenCosts = null;
    this.tokenContributions = null;
    this.legalBodies = null;
    this.capBreakerModel = null;
    this.modelWeights = null;
    this.modelCurves = null;
    this.modelOverallScale = null;
    this.glossary = null;
    this.tuningParser = null;
    this._essentialLoaded = false;
    this._heavyLoaded = false;
  }

  _unwrap(raw) { return (raw && raw.data) ? raw.data : raw; }

  async loadEssential() {
    if (this._essentialLoaded) return;
    try {
      this.definitions = this._unwrap(require('../assets/data/definitions.js'));
      this.tierRequirements = this._unwrap(require('../assets/data/tier_requirements.js'));
      this.tokenCosts = this._unwrap(require('../assets/data/token_costs.js'));
      this.tokenContributions = this._unwrap(require('../assets/data/token_contributions.js'));
      this.legalBodies = this._unwrap(require('../assets/data/legal_bodies.js'));
      this.glossary = this._unwrap(require('../assets/data/glossary.js'));
      this.uiPresentation = this._unwrap(require('../assets/data/ui_presentation.js'));

      try {
        const content = require('../assets/data/progression_attributes.js');
        this.tuningParser = new TuningParser();
        this.tuningParser.parse(content);
      } catch (e) { console.warn('[DL] Tuning unavailable:', e.message); }

      this._essentialLoaded = true;
      console.log('[DL] Essential loaded:', this.definitions ? this.definitions.length : 0, 'defs');
    } catch (e) {
      console.error('[DL] Essential load error:', e.message);
    }
  }

  async loadHeavy() {
    if (this._heavyLoaded) return;
    try {
      this.capBreakerModel = this._unwrap(require('../assets/data/cap_breaker_model.js'));
      if (this.capBreakerModel) {
        this.modelWeights = this.capBreakerModel.weights;
        this.modelCurves = this.capBreakerModel.curves;
        this.modelOverallScale = this.capBreakerModel.overallScale;
      }
      this._heavyLoaded = true;
    } catch (e) { console.error('[DL] Heavy load error:', e.message); }
  }

  get attributes() { return DEFAULT_ATTRIBUTES; }

  getOvr(position, heightInches, ratings) {
    if (!this.tuningParser || !ratings) return 25;
    const idx = typeof position === 'number' ? position : ['PG','SG','SF','PF','C'].indexOf(position);
    try { return Math.round(this.tuningParser.computeOvr(idx >= 0 ? idx : 0, heightInches, ratings)); }
    catch (e) { return 25; }
  }

  getAttributeCaps(position, heightInches, weightLb, wingspanInches) {
    if (!this.tuningParser) return new Array(21).fill(99);
    const idx = typeof position === 'number' ? position : ['PG','SG','SF','PF','C'].indexOf(position);
    try { return this.tuningParser.computeAttributeCaps(idx >= 0 ? idx : 0, heightInches, weightLb, wingspanInches); }
    catch (e) { return new Array(21).fill(99); }
  }

  getAnimTabs() {
    if (!this.glossary) return [];
    const tabs = this.glossary['Anim Glossary Tabs'] || [];
    return tabs.map(tab => ({
      id: tab['Tab ID'], name: tab['Tab Name'] || {},
      groups: (tab['Anim Groups'] || []).map(g => ({
        id: g['Anim Type'], name: g['Group Name'] || {},
        anims: (g['Anims'] || []).map(a => ({ id: a['Anim ID'], name: a['Anim Name'] || {} })),
      })),
    }));
  }

  getTierRequirementsForBadge(badgeId) {
    if (!this.tierRequirements || !Array.isArray(this.tierRequirements)) return [];
    return this.tierRequirements.filter(r => r.badge === badgeId);
  }
}

const DEFAULT_ATTRIBUTES = [
  { index: 0, name: 'close_shot', discipline: 'finishing', colour: '#3764B3' },
  { index: 1, name: 'driving_layup', discipline: 'finishing', colour: '#3764B3' },
  { index: 2, name: 'driving_dunk', discipline: 'finishing', colour: '#3764B3' },
  { index: 3, name: 'standing_dunk', discipline: 'finishing', colour: '#3764B3' },
  { index: 4, name: 'post_control', discipline: 'finishing', colour: '#3764B3' },
  { index: 5, name: 'mid_range', discipline: 'shooting', colour: '#61AF57' },
  { index: 6, name: 'three_point', discipline: 'shooting', colour: '#61AF57' },
  { index: 7, name: 'free_throw', discipline: 'shooting', colour: '#61AF57' },
  { index: 8, name: 'pass_accuracy', discipline: 'playmaking', colour: '#E29754' },
  { index: 9, name: 'ball_handle', discipline: 'playmaking', colour: '#E29754' },
  { index: 10, name: 'speed_with_ball', discipline: 'playmaking', colour: '#E29754' },
  { index: 11, name: 'interior_defense', discipline: 'defense', colour: '#DE574B' },
  { index: 12, name: 'perimeter_defense', discipline: 'defense', colour: '#DE574B' },
  { index: 13, name: 'steal', discipline: 'defense', colour: '#DE574B' },
  { index: 14, name: 'block', discipline: 'defense', colour: '#DE574B' },
  { index: 15, name: 'offensive_rebound', discipline: 'rebounding', colour: '#9785EA' },
  { index: 16, name: 'defensive_rebound', discipline: 'rebounding', colour: '#9785EA' },
  { index: 17, name: 'speed', discipline: 'physicals', colour: '#A27D32' },
  { index: 18, name: 'agility', discipline: 'physicals', colour: '#A27D32' },
  { index: 19, name: 'strength', discipline: 'physicals', colour: '#A27D32' },
  { index: 20, name: 'vertical', discipline: 'physicals', colour: '#A27D32' },
];

module.exports = { DatasetLoader };
