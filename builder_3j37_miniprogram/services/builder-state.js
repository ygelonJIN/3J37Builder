// builder-state.js - 核心构建状态管理
const { Position, POSITION_LABELS, BadgeTier, BADGE_TIER_KEYS, NATIVE_NAMES, ATTRIBUTE_KEYS, DISCIPLINE_ATTRS } = require('../models/enums');

class BuilderState {
  constructor(datasetLoader, tuningParser, capBreakerEngine) {
    this._loader = datasetLoader;
    this._tuning = tuningParser;
    this._cbEngine = capBreakerEngine;
    
    this._position = 0;
    this._heightInches = 75;
    this._weightLb = 185;
    this._wingspanInches = 75;
    
    this._baseRatings = new Array(21).fill(25);
    this._finalRatings = new Array(21).fill(25);
    this._physicalCaps = new Array(21).fill(99);
    this._userTouched = new Array(21).fill(false);
    
    this._appliedCapBreakers = {};
    this._lockedAttributes = new Set();
    
    this._goalRatings = {};
    this._goalActive = new Set();
    this._goalConstrainedFloors = {};
    this._goalFromBadgesMoves = new Set();
    this._goalData = { badges: [], moves: [], attributes: [] };
    
    this._equippedBadges = {};
    
    this._listeners = [];
    this._recalculatePhysicalCaps();
  }

  addListener(fn) { this._listeners.push(fn); }
  removeListener(fn) { this._listeners = this._listeners.filter(f => f !== fn); }
  _notify() { this._listeners.forEach(fn => fn()); }

  get position() { return this._position; }
  get heightInches() { return this._heightInches; }
  get weightLb() { return this._weightLb; }
  get wingspanInches() { return this._wingspanInches; }
  get ratings() { return [...this._finalRatings]; }
  get baseRatings() { return [...this._baseRatings]; }
  get physicalCaps() { return [...this._physicalCaps]; }
  get userTouched() { return [...this._userTouched]; }
  get equippedBadges() { return { ...this._equippedBadges }; }
  get goalData() { return this._goalData; }
  get loader() { return this._loader; }

  get heightDisplay() {
    const feet = Math.floor(this._heightInches / 12);
    const inches = this._heightInches % 12;
    return `${feet}'${inches}"`;
  }

  get weightDisplay() { return `${this._weightLb} lbs`; }

  get wingspanDisplay() {
    const feet = Math.floor(this._wingspanInches / 12);
    const inc = this._wingspanInches % 12;
    return `${feet}'${inc}"`;
  }

  get overallRating() {
    if (!this._loader) return 25;
    return this._loader.getOvr(POSITION_LABELS[this._position], this._heightInches, this._baseRatings);
  }

  getAttributeState(attrIndex) {
    const appliedGains = this._appliedCapBreakers[attrIndex] || [];
    const totalGain = appliedGains.reduce((s, g) => s + g, 0);
    return {
      baseValue: this._baseRatings[attrIndex],
      capBreakerGain: totalGain,
      baseCap: this._physicalCaps[attrIndex],
      appliedGains: [...appliedGains],
      finalValue: this._baseRatings[attrIndex] + totalGain,
      hasCapBreakers: totalGain > 0,
    };
  }

  setPosition(pos) {
    this._position = pos;
    this._recalculatePhysicalCaps();
    this._recalculateAllRatings();
    this._notify();
  }

  setHeight(inches) {
    this._heightInches = inches;
    this._recalculatePhysicalCaps();
    this._recalculateAllRatings();
    this._notify();
  }

  setWeight(lb) {
    this._weightLb = lb;
    this._recalculatePhysicalCaps();
    this._recalculateAllRatings();
    this._notify();
  }

  setWingspan(inches) {
    this._wingspanInches = inches;
    this._recalculatePhysicalCaps();
    this._recalculateAllRatings();
    this._notify();
  }

  setRating(attrIndex, value) {
    const cap = this._physicalCaps[attrIndex];
    const clamped = Math.max(25, Math.min(cap, value));
    const oldVal = this._baseRatings[attrIndex];
    this._baseRatings[attrIndex] = clamped;
    this._userTouched[attrIndex] = true;
    
    if (clamped > oldVal) {
      this._applyConstraintsAndOvrBudget(attrIndex, oldVal);
    }
    this._recalculateFinalRatings();
    this._notify();
  }

  isLocked(attrIndex) { return this._lockedAttributes.has(attrIndex); }
  
  toggleLock(attrIndex) {
    if (this._lockedAttributes.has(attrIndex)) {
      this._lockedAttributes.delete(attrIndex);
    } else {
      this._lockedAttributes.add(attrIndex);
    }
    this._notify();
  }

  _recalculatePhysicalCaps() {
    if (this._loader && this._loader.tuningParser && this._loader.tuningParser.isParsed) {
      this._physicalCaps = this._loader.getAttributeCaps(POSITION_LABELS[this._position], this._heightInches, this._weightLb, this._wingspanInches);
    } else {
      this._physicalCaps = new Array(21).fill(99);
    }
  }

  _recalculateFinalRatings() {
    for (let i = 0; i < 21; i++) {
      const gains = this._appliedCapBreakers[i] || [];
      const cbGain = gains.reduce((s, g) => s + g, 0);
      this._finalRatings[i] = Math.min(this._baseRatings[i] + cbGain, 99);
    }
  }

  _recalculateAllRatings() {
    for (let i = 0; i < 21; i++) {
      if (this._baseRatings[i] > this._physicalCaps[i]) {
        this._baseRatings[i] = this._physicalCaps[i];
      }
    }
    this._recalculateCapBreakerGains();
    this._recalculateFinalRatings();
  }

  _applyConstraintsAndOvrBudget(changedIndex, oldValue) {
    if (!this._loader || !this._loader.tuningParser || !this._loader.tuningParser.isParsed) return;
    const constrained = this._loader.applyConstraints(this._heightInches, [...this._baseRatings]);
    for (let i = 0; i < 21; i++) {
      if (this._lockedAttributes.has(i)) continue;
      if (this._goalActive.has(i)) continue;
      if (constrained[i] > this._baseRatings[i]) {
        this._baseRatings[i] = Math.min(constrained[i], this._physicalCaps[i]);
      }
    }
  }

  // Cap Breaker methods
  getNextCapBreakerGain(attrIndex) {
    const appliedCount = (this._appliedCapBreakers[attrIndex] || []).length;
    if (appliedCount >= 5) return null;
    if (!this._cbEngine || !this._cbEngine.hasModelData) return null;
    
    const currentRating = this._baseRatings[attrIndex] + (this._appliedCapBreakers[attrIndex] || []).reduce((s, g) => s + g, 0);
    if (currentRating >= this._physicalCaps[attrIndex]) return null;
    
    const values = {};
    for (let i = 0; i < 21; i++) {
      values[NATIVE_NAMES[i] || ATTRIBUTE_KEYS[i]] = this._baseRatings[i];
    }
    
    const body = {
      position: POSITION_LABELS[this._position],
      height: this._heightInches,
      weight: this._weightLb,
      wingspan: this._wingspanInches,
    };
    
    const gains = this._cbEngine.getChainedGains(attrIndex, this._baseRatings[attrIndex], values, body, this._physicalCaps);
    if (gains.length > appliedCount) {
      return gains[appliedCount];
    }
    return null;
  }

  applyCapBreaker(attrIndex) {
    const gain = this.getNextCapBreakerGain(attrIndex);
    if (gain === null) return false;
    if (!this._appliedCapBreakers[attrIndex]) this._appliedCapBreakers[attrIndex] = [];
    this._appliedCapBreakers[attrIndex].push(gain);
    this._recalculateFinalRatings();
    this._notify();
    return true;
  }

  applyCapBreakerWithGain(attrIndex, gain) {
    if (!this._appliedCapBreakers[attrIndex]) this._appliedCapBreakers[attrIndex] = [];
    this._appliedCapBreakers[attrIndex].push(gain);
    this._recalculateFinalRatings();
  }

  removeCapBreaker(attrIndex) {
    if (!this._appliedCapBreakers[attrIndex] || this._appliedCapBreakers[attrIndex].length === 0) return false;
    this._appliedCapBreakers[attrIndex].pop();
    this._recalculateFinalRatings();
    this._notify();
    return true;
  }

  clearAllCapBreakers() {
    this._appliedCapBreakers = {};
    this._recalculateFinalRatings();
    this._notify();
  }

  getAppliedCapBreakerGains(attrIndex) {
    return [...(this._appliedCapBreakers[attrIndex] || [])];
  }

  getCapBreakerSequence(attrIndex) {
    if (!this._cbEngine || !this._cbEngine.hasModelData) return [];
    const values = {};
    for (let i = 0; i < 21; i++) {
      values[NATIVE_NAMES[i] || ATTRIBUTE_KEYS[i]] = this._baseRatings[i];
    }
    const body = {
      position: POSITION_LABELS[this._position],
      height: this._heightInches,
      weight: this._weightLb,
      wingspan: this._wingspanInches,
    };
    return this._cbEngine.getChainedGains(attrIndex, this._baseRatings[attrIndex], values, body, this._physicalCaps);
  }

  _recalculateCapBreakerGains() {
    // Recalculate all cap breakers based on current base ratings
    for (const attrStr of Object.keys(this._appliedCapBreakers)) {
      const attrIndex = parseInt(attrStr);
      const gains = this._appliedCapBreakers[attrIndex];
      if (!gains || gains.length === 0) continue;
      const sequence = this.getCapBreakerSequence(attrIndex);
      this._appliedCapBreakers[attrIndex] = sequence.slice(0, gains.length);
    }
  }

  // Badge methods
  equipBadge(badgeId, tier) {
    this._equippedBadges[badgeId] = tier;
    this._notify();
  }

  unequipBadge(badgeId) {
    delete this._equippedBadges[badgeId];
    this._notify();
  }

  getBadgeStatus(badgeId) {
    return this._equippedBadges[badgeId] || null;
  }

  _autoDowngradeBadges() {
    // Auto-downgrade badges that no longer meet requirements
  }

  // Goal methods
  setGoalAttribute(attrIndex, value) {
    this._goalActive.add(attrIndex);
    this._goalRatings[attrIndex] = Math.max(25, Math.min(this._physicalCaps[attrIndex], value));
    this._baseRatings[attrIndex] = this._goalRatings[attrIndex];
    this._userTouched[attrIndex] = true;
    this._applyConstraintsAndOvrBudget(attrIndex, 25);
    this._recalculateFinalRatings();
    this._notify();
  }

  removeGoalAttribute(attrIndex) {
    this._goalActive.delete(attrIndex);
    delete this._goalRatings[attrIndex];
    this._recalculateGoalFloors();
    this._notify();
  }

  toggleGoalAttribute(attrIndex) {
    if (this._goalActive.has(attrIndex)) {
      this.removeGoalAttribute(attrIndex);
    } else {
      this.setGoalAttribute(attrIndex, this._baseRatings[attrIndex]);
    }
  }

  addGoalBadge(badge) {
    this._goalData.badges.push(badge);
    this._applyGoalConstraintsFromBadgesMoves();
    this._notify();
  }

  removeGoalBadge(badgeId) {
    this._goalData.badges = this._goalData.badges.filter(b => b.badgeId !== badgeId);
    this._applyGoalConstraintsFromBadgesMoves();
    this._notify();
  }

  addGoalMove(move) {
    this._goalData.moves.push(move);
    this._applyGoalConstraintsFromBadgesMoves();
    this._notify();
  }

  removeGoalMove(moveId) {
    this._goalData.moves = this._goalData.moves.filter(m => m.id !== moveId);
    this._applyGoalConstraintsFromBadgesMoves();
    this._notify();
  }

  _applyGoalConstraintsFromBadgesMoves() {
    for (const idx of this._goalFromBadgesMoves) {
      if (!this._goalData.attributes.some(a => a.attributeIndex === idx)) {
        this._goalActive.delete(idx);
        delete this._goalRatings[idx];
      }
    }
    this._goalFromBadgesMoves.clear();
    this._recalculateGoalFloors();
    this._recalculateCapBreakerGains();
    this._recalculateFinalRatings();
  }

  _recalculateGoalFloors() {
    this._goalConstrainedFloors = {};
    if (this._goalActive.size === 0) return;
    for (const idx of this._goalActive) {
      const val = this._goalRatings[idx] || 25;
      this._goalConstrainedFloors[idx] = val;
    }
  }

  // Token/Slot calculations
  getTokenBudget() {
    if (!this._loader || !this._loader.tokenContributions) return new Array(6).fill(0);
    const budget = new Array(6).fill(0);
    const contributions = this._loader.tokenContributions;
    if (Array.isArray(contributions)) {
      for (const entry of contributions) {
        if (entry.height_inches !== this._heightInches) continue;
        const attrIdx = entry.attribute;
        const rating = this._baseRatings[attrIdx];
        if (entry.tokens && entry.tokens.length >= 6) {
          for (let d = 0; d < 6; d++) {
            budget[d] += entry.tokens[d] || 0;
          }
        }
      }
    }
    return budget;
  }

  getAttributeCaps() {
    return [...this._physicalCaps];
  }
}

module.exports = { BuilderState };
