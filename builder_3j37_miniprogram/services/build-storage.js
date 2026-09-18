const STORAGE_KEY = 'myb_builds_v1';

class BuildStorageService {
  constructor() {
    this._builds = [];
    this._loaded = false;
  }
  
  get builds() { return [...this._builds]; }
  get count() { return this._builds.length; }
  get isLoaded() { return this._loaded; }
  
  // 加载已保存的构建
  loadBuilds() {
    if (this._loaded) return;
    try {
      const stored = wx.getStorageSync(STORAGE_KEY);
      if (stored) {
        this._builds = JSON.parse(stored);
        this._builds.sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));
      }
    } catch (e) {
      console.error('[BuildStorage] Error loading:', e);
      this._builds = [];
    }
    this._loaded = true;
  }
  
  // 保存构建
  saveBuild(state, name) {
    const now = new Date();
    const id = `${now.getTime()}_${this._builds.length}`;
    
    // 收集装备的徽章
    const equippedBadges = {};
    for (const [badgeId, tier] of Object.entries(state.equippedBadges)) {
      if (tier != null) equippedBadges[badgeId] = tier;
    }
    
    // 收集已应用的破帽器
    const appliedCapBreakers = {};
    for (let i = 0; i < 21; i++) {
      const gains = state.getAppliedCapBreakerGains(i);
      if (gains.length > 0) appliedCapBreakers[i] = [...gains];
    }
    
    const build = {
      id,
      name: name || `Build ${this._builds.length + 1}`,
      position: state.position,
      heightInches: state.heightInches,
      weightLb: state.weightLb,
      wingspanInches: state.wingspanInches,
      baseRatings: [...state.baseRatings],
      equippedBadgeTiers: equippedBadges,
      appliedCapBreakers,
      overallRating: state.overallRating,
      createdAt: now.toISOString(),
      updatedAt: now.toISOString(),
    };
    
    this._builds.unshift(build);
    this._persist();
    return build;
  }
  
  // 重命名
  renameBuild(id, newName) {
    const index = this._builds.findIndex(b => b.id === id);
    if (index === -1) return false;
    
    this._builds[index].name = newName;
    this._builds[index].updatedAt = new Date().toISOString();
    this._persist();
    return true;
  }
  
  // 删除
  deleteBuild(id) {
    const index = this._builds.findIndex(b => b.id === id);
    if (index === -1) return false;
    
    this._builds.splice(index, 1);
    this._persist();
    return true;
  }
  
  // 获取
  getBuild(id) {
    return this._builds.find(b => b.id === id) || null;
  }
  
  // 应用已保存的构建到状态
  applyBuild(build, state) {
    state.setPosition(build.position);
    state.setHeight(build.heightInches);
    state.setWeight(build.weightLb);
    state.setWingspan(build.wingspanInches);
    for (let i = 0; i < 21 && i < build.baseRatings.length; i++) {
      state.setRating(i, build.baseRatings[i]);
    }
    state.clearAllCapBreakers();
    for (const [attrIdx, gains] of Object.entries(build.appliedCapBreakers || {})) {
      for (const gain of gains) {
        state.applyCapBreakerWithGain(parseInt(attrIdx), gain);
      }
    }
    for (const [badgeId, tier] of Object.entries(build.equippedBadgeTiers || {})) {
      state.equipBadge(parseInt(badgeId), tier);
    }
  }
  
  // 持久化
  _persist() {
    try {
      wx.setStorageSync(STORAGE_KEY, JSON.stringify(this._builds));
    } catch (e) {
      console.error('[BuildStorage] Error saving:', e);
    }
  }
}

module.exports = { BuildStorageService };
