const app = getApp();
const { t } = require('../../i18n/index');
const { POSITION_LABELS, DISCIPLINE_ATTRS, DISCIPLINE_COLORS, ATTRIBUTE_KEYS, BadgeTier, BADGE_TIER_LABELS, BADGE_TIER_KEYS, BADGE_TIER_COLORS } = require('../../models/enums');
const { BuilderState } = require('../../services/builder-state');
const { DatasetLoader } = require('../../services/dataset-loader');
const { TuningParser } = require('../../services/tuning-parser');
const { CapBreakerEngine } = require('../../services/cap-breaker-engine');
const { BuildStorageService } = require('../../services/build-storage');

const DISC_NAMES = {1:'Finishing',2:'Shooting',3:'Playmaking',4:'Defense',5:'Rebounding',6:'Physicals'};
const ATTR_EN = ['Close Shot','Driving Layup','Driving Dunk','Standing Dunk','Post Control','Mid Range','Three Point','Free Throw','Pass Accuracy','Ball Handle','Speed With Ball','Interior Defense','Perimeter Defense','Steal','Block','Offensive Rebound','Defensive Rebound','Speed','Agility','Strength','Vertical'];
const TIER_COLORS = {'':'','bronze':'#CD7F32','silver':'#C0C0C0','gold':'#E0AE40','hall_of_fame':'#9B59B6','legend':'#FF6B6B'};

Page({
  data: {
    loading: true, loadingMsg: 'Loading...', locale: 'zh_CN', statusBarHeight: 20, cardsHeight: 200,
    position: 0, posLabel: 'PG', posList: [{code:0,label:'PG'},{code:1,label:'SG'},{code:2,label:'SF'},{code:3,label:'PF'},{code:4,label:'C'}],
    heightInches: 75, weightLb: 185, wingspanInches: 75,
    heightDisplay: "6'3\"", wingspanDisplay: "6'3\"", heightCm: 191, weightKg: 84, wingspanCm: 191,
    overallRating: 25, ovrPrecise: '25.0',
    cardBody: false, cardMinimap: false, cardGoal: false,
    minimapRows: [], discGroups: [],
    goalBadgeCount: 0, goalMoveCount: 0, goalAttrCount: 0,
    goalBadges: [], goalMoves: [], goalAttrs: [], goalAttrReqs: [],
    moreOpen: false,
    showBadges: false, showMoves: false, showMyB: false,
    showAddGoal: false, showBadgeDetail: false,
    badgeDetail: {}, badgeSearchQuery: '', moveSearchQuery: '',
    allBadges: [], filteredBadgeGroups: [], savedBuilds: [],
    tokenRemaining: 0, tokenBudget: 0, tokenByDisc: [],
    animTabs: [], selectedAnimTab: 0, filteredAnimGroups: [],
    goalTabs: ['Badges','Moves','Attributes'], goalTabIndex: 0,
    goalSearchQuery: '', goalSelectedId: null, goalSelectedAttrIndex: -1,
    selectedTier: null, selectedTierLabel: '', tierDropdownOpen: false,
    tierOptions: [{code:1,label:'Bronze'},{code:2,label:'Silver'},{code:3,label:'Gold'},{code:4,label:'Hall of Fame'},{code:5,label:'Legend'}],
    goalTargetValue: 25, goalDialogError: '',
    filteredBadges: [], filteredMoves: [], filteredGoalAttrs: [],
  },
  _state: null, _loader: null, _cbEngine: null, _storage: null,

  onLoad() {
    const sys = wx.getWindowInfo ? wx.getWindowInfo() : wx.getSystemInfoSync();
    this.setData({ locale: app.globalData.locale, statusBarHeight: sys.statusBarHeight || 20, cardsHeight: (sys.statusBarHeight || 20) + 280 });
    this._init();
  },
  onShow() { this.setData({ locale: app.globalData.locale }); if (this._state) this._refresh(); },
  onScroll() { if (this.data.moreOpen) this.setData({ moreOpen: false }); },

  async _init() {
    try {
      this.setData({ loadingMsg: 'Loading data...' });
      this._loader = new DatasetLoader();
      await this._loader.loadEssential();
      this.setData({ loadingMsg: 'Loading model...' });
      await this._loader.loadHeavy();
      this._cbEngine = new CapBreakerEngine();
      if (this._loader.modelWeights && this._loader.modelCurves) {
        this._cbEngine.loadModelData(this._loader.modelWeights, this._loader.modelCurves, this._loader.modelOverallScale);
      }
      this._storage = new BuildStorageService();
      this._storage.loadBuilds();
      this._state = new BuilderState(this._loader, null, this._cbEngine);
      this._refresh();
      this.setData({ loading: false });
    } catch (e) {
      console.error('[Index] Init error:', e);
      this.setData({ loading: false, loadingMsg: 'Error: ' + e.message });
    }
  },

  _refresh() {
    if (!this._state) return;
    const s = this._state;
    const hF = Math.floor(s.heightInches/12), hI = s.heightInches%12;
    const wF = Math.floor(s.wingspanInches/12), wI = s.wingspanInches%12;

    // Minimap
    const mmRows = [];
    for (let d = 1; d <= 6; d++) {
      const ais = DISCIPLINE_ATTRS[d] || [];
      const c = DISCIPLINE_COLORS[d];
      for (let i = 0; i < ais.length; i += 2) {
        const row = [];
        for (let j = i; j < Math.min(i+2, ais.length); j++) {
          const ai = ais[j]; const v = s.ratings[ai], cap = s.physicalCaps[ai];
          const atCap = v >= cap, locked = s.isLocked(ai);
          row.push({ n: t(ATTRIBUTE_KEYS[ai])||ATTR_EN[ai], v, cap, c, vc: (atCap||locked)?'#6F6B60':c, nc: (atCap||locked)?'#6F6B60':'#B09B74', idx: ai });
        }
        mmRows.push(row);
      }
    }

    // Disc groups with expanded badge chips + cap breaker slots
    const dg = [];
    for (let d = 1; d <= 6; d++) {
      const ais = DISCIPLINE_ATTRS[d] || [];
      const color = DISCIPLINE_COLORS[d];
      const attrs = ais.map(ai => {
        const st = s.getAttributeState(ai);
        const cbG = st.capBreakerGain;
        const ga = s._goalActive.has(ai);
        const gv = s._goalRatings[ai] || 25;
        // Badge chips (name + color from tierRequirements)
        const relBadges = this._getRelatedBadgeChips(ai);
        // Cap breaker slots
        const cbSeq = s.getCapBreakerSequence(ai);
        const appliedCount = (s._appliedCapBreakers[ai] || []).length;
        const cbMaxValue = s.baseRatings[ai] + cbSeq.reduce((a,b)=>a+b,0);
        const cbSlots = [];
        for (let si = 0; si < 5; si++) {
          const available = si < cbSeq.length;
          const gain = available ? cbSeq[si] : null;
          cbSlots.push({ gain, applied: si < appliedCount, isNext: si === appliedCount && available, available });
        }
        return {
          index: ai, name: t(ATTRIBUTE_KEYS[ai])||ATTR_EN[ai],
          value: st.finalValue, cap: st.baseCap, locked: s.isLocked(ai),
          cbGain: cbG, goalActive: ga, goalVal: gv,
          isMaxed: st.finalValue >= st.baseCap && cbG === 0,
          expanded: false, hasError: false, errMsg: '',
          relBadges, cbSeq, cbMaxValue, cbSlots,
        };
      });
      dg.push({ d, name: DISC_NAMES[d], color, attrs, tokRem: 0, tokBud: 0, sltRem: 0, sltBud: 0 });
    }

    // Goal data
    const goalBadges = (s._goalData.badges||[]).map(b => ({
      id: b.badgeId, name: b.badgeName||('Badge '+b.badgeId),
      tier: BADGE_TIER_LABELS[b.tier]||'', tierColor: TIER_COLORS[BADGE_TIER_KEYS[b.tier]||'']||'#E0AE40',
    }));
    const goalMoves = (s._goalData.moves||[]).map(m => ({ id: m.id||m.moveId, name: m.name||('Move '+m.id) }));
    const goalAttrs = [];
    for (const idx of s._goalActive) {
      goalAttrs.push({ index: idx, name: t(ATTRIBUTE_KEYS[idx])||ATTR_EN[idx], value: s._goalRatings[idx]||25, cap: s._physicalCaps[idx] });
    }

    // Badge panel data
    const allBg = this._getBadgePanelData();
    const filteredBadgeGroups = this._filterBadgeGroups(allBg, this.data.badgeSearchQuery);

    // Anim tabs
    const animTabs = this._getAnimTabs();
    const filteredAnimGroups = this._filterAnimGroups(animTabs, this.data.selectedAnimTab, this.data.moveSearchQuery);

    // Token budget
    const tokenBudget = s.getTokenBudget ? s.getTokenBudget() : new Array(6).fill(0);
    const tokenRemaining = tokenBudget.reduce((a,b)=>a+b,0);
    const tokenByDisc = [];
    for (let d = 1; d <= 6; d++) {
      tokenByDisc.push({ disc: d, name: DISC_NAMES[d], color: DISCIPLINE_COLORS[d], budget: tokenBudget[d-1]||0, remaining: tokenBudget[d-1]||0, slotBudget: 0, slotRemaining: 0 });
    }

    const savedBuilds = this._storage ? this._storage.builds.map(b => ({
      ...b, posLabel: POSITION_LABELS[b.position]||'PG',
      heightDisplay: `${Math.floor(b.heightInches/12)}'${b.heightInches%12}"`,
    })) : [];

    this.setData({
      posLabel: POSITION_LABELS[s.position],
      heightInches: s.heightInches, weightLb: s.weightLb, wingspanInches: s.wingspanInches,
      heightDisplay: `${hF}'${hI}"`, wingspanDisplay: `${wF}'${wI}"`,
      heightCm: Math.round(s.heightInches*2.54), weightKg: Math.round(s.weightLb*0.453592), wingspanCm: Math.round(s.wingspanInches*2.54),
      overallRating: s.overallRating, ovrPrecise: (typeof s.overallRating==='number'?s.overallRating:25).toFixed(1),
      minimapRows: mmRows, discGroups: dg,
      goalBadgeCount: goalBadges.length, goalMoveCount: goalMoves.length, goalAttrCount: goalAttrs.length,
      goalBadges, goalMoves, goalAttrs, goalAttrReqs: [],
      allBadges: allBg, filteredBadgeGroups, savedBuilds,
      animTabs, filteredAnimGroups,
      tokenRemaining, tokenBudget: tokenBudget.reduce((a,b)=>a+b,0), tokenByDisc,
    });
  },

  _getRelatedBadgeChips(ai) {
    if (!this._loader || !Array.isArray(this._loader.tierRequirements)) return [];
    const related = [];
    const seen = new Set();
    for (const tr of this._loader.tierRequirements) {
      if (seen.has(tr.badge)) continue;
      if (!tr.requirements || !Array.isArray(tr.requirements)) continue;
      const hasAttr = tr.requirements.some(r => r.attribute === ai);
      if (!hasAttr) continue;
      seen.add(tr.badge);
      const def = Array.isArray(this._loader.definitions) ? this._loader.definitions.find(d => d.badge === tr.badge) : null;
      const name = (def && (def.displayName || def.name)) || tr.badgeName || ('Badge '+tr.badge);
      const discIdx = def ? def.discipline : 1;
      const color = DISCIPLINE_COLORS[discIdx] || '#B09B74';
      related.push({ id: tr.badge, name, color });
      if (related.length >= 8) break;
    }
    return related;
  },

  _getBadgePanelData() {
    if (!this._loader || !Array.isArray(this._loader.definitions)) return [];
    const defs = this._loader.definitions;
    const grouped = {};
    for (const def of defs) {
      const disc = def.discipline || 1;
      const discName = DISC_NAMES[disc] || 'Unknown';
      const discColor = DISCIPLINE_COLORS[disc] || '#B09B74';
      if (!grouped[disc]) grouped[disc] = { disc, name: discName, color: discColor, badges: [], tokenRemaining: 0, tokenBudget: 0, slotRemaining: 0, slotBudget: 0 };
      const equipped = this._state ? this._state.equippedBadges[def.badge] : null;
      const tierKey = equipped ? BADGE_TIER_KEYS[equipped] : '';
      grouped[disc].badges.push({
        id: def.badge, name: def.displayName || def.name || ('Badge '+def.badge),
        equipped: !!equipped, unlocked: true,
        borderColor: equipped ? (TIER_COLORS[tierKey]||'#E0AE40') : 'rgba(176,155,116,0.3)',
        tierColor: equipped ? (TIER_COLORS[tierKey]||'#E0AE40') : 'transparent',
      });
    }
    return Object.values(grouped).sort((a,b) => a.disc - b.disc);
  },

  _filterBadgeGroups(groups, query) {
    if (!query) return groups;
    const q = query.toLowerCase();
    return groups.map(g => ({
      ...g,
      badges: g.badges.filter(b => b.name.toLowerCase().includes(q)),
    })).filter(g => g.badges.length > 0);
  },

  _getAnimTabs() {
    if (!this._loader || !this._loader.glossary) return [];
    const tabs = this._loader.glossary['Anim Glossary Tabs'] || [];
    const locale = this.data.locale === 'zh_CN' ? 'ZH-HANS' : 'EN';
    return tabs.map(tab => ({
      id: tab['Tab ID'],
      name: (tab['Tab Name'] || {})[locale] || (tab['Tab Name'] || {}).EN || tab['Tab ID'],
      groups: (tab['Anim Groups'] || []).map(g => ({
        id: g['Anim Type'], expanded: false,
        name: (g['Group Name'] || {})[locale] || (g['Group Name'] || {}).EN || g['Anim Type'],
        anims: (g['Anims'] || []).map(a => ({
          id: a['Anim ID'],
          name: (a['Anim Name'] || {})[locale] || (a['Anim Name'] || {}).EN || a['Anim ID'],
        })),
      })),
    }));
  },

  _filterAnimGroups(tabs, tabIndex, query) {
    if (!tabs || !tabs[tabIndex]) return [];
    const tab = tabs[tabIndex];
    if (!query) return tab.groups;
    const q = query.toLowerCase();
    return tab.groups.filter(g => g.name.toLowerCase().includes(q) || g.anims.some(a => a.name.toLowerCase().includes(q)));
  },

  toggleCard(e) {
    const c = e.currentTarget.dataset.card;
    if (c==='body') this.setData({cardBody:!this.data.cardBody});
    else if (c==='minimap') this.setData({cardMinimap:!this.data.cardMinimap});
    else if (c==='goal') this.setData({cardGoal:!this.data.cardGoal});
  },

  onPosChange(e) { this._state.setPosition(e.currentTarget.dataset.code); this._refresh(); },

  onBodyStep(e) {
    const field = e.currentTarget.dataset.field;
    const dir = parseInt(e.currentTarget.dataset.dir);
    if (field==='height') this._state.setHeight(Math.max(69,Math.min(88,this._state.heightInches+dir)));
    else if (field==='weight') this._state.setWeight(Math.max(135,Math.min(290,this._state.weightLb+dir*5)));
    else if (field==='wingspan') this._state.setWingspan(Math.max(69,Math.min(88,this._state.wingspanInches+dir)));
    this._refresh();
  },

  toggleAttrExp(e) {
    const {d,ai}=e.currentTarget.dataset;
    const groups=this.data.discGroups.map(g=>{
      if(g.d===d){g.attrs=g.attrs.map(a=>{if(a.index===parseInt(ai))a.expanded=!a.expanded;return a;});}
      return g;
    });
    this.setData({discGroups:groups});
  },

  onAttrStep(e) {
    const ai=parseInt(e.currentTarget.dataset.ai);
    const dir=parseInt(e.currentTarget.dataset.dir);
    if(this._state.isLocked(ai))return;
    this._state.setRating(ai,this._state.baseRatings[ai]+dir);
    this._refresh();
  },

  onValBlur(e) {
    const ai=parseInt(e.currentTarget.dataset.ai);
    const v=parseInt(e.detail.value);
    if(isNaN(v))return;
    this._state.setRating(ai,v);
    this._refresh();
  },

  toggleLock(e) { this._state.toggleLock(e.currentTarget.dataset.ai); this._refresh(); },

  onGoalStep(e) {
    const ai=parseInt(e.currentTarget.dataset.ai);
    const dir=parseInt(e.currentTarget.dataset.dir);
    this._state.setGoalAttribute(ai,(this._state._goalRatings[ai]||25)+dir);
    this._refresh();
  },

  removeGoalItem(e) {
    const type = e.currentTarget.dataset.type;
    if (type==='badge') this._state.removeGoalBadge(parseInt(e.currentTarget.dataset.id));
    else if (type==='move') this._state.removeGoalMove(parseInt(e.currentTarget.dataset.id));
    else if (type==='attr') this._state.removeGoalAttribute(parseInt(e.currentTarget.dataset.ai));
    this._refresh();
  },

  onBadgeChipTap(e) {
    const bid = parseInt(e.currentTarget.dataset.bid);
    const def = Array.isArray(this._loader.definitions) ? this._loader.definitions.find(d => d.badge === bid) : null;
    if (!def) return;
    const tiers = [];
    for (let tc = 1; tc <= 5; tc++) {
      tiers.push({ code: tc, label: BADGE_TIER_LABELS[tc], key: BADGE_TIER_KEYS[tc], eq: this._state.equippedBadges[bid]===tc, ul: true });
    }
    this.setData({ showBadgeDetail: true, badgeDetail: { id: bid, name: def.displayName||def.name||('Badge '+bid), tiers } });
  },

  closeBadgeDetail() { this.setData({ showBadgeDetail: false }); },

  onToggleBadge(e) {
    const bid=parseInt(e.currentTarget.dataset.bid);
    const tier=parseInt(e.currentTarget.dataset.tier);
    if(this._state.equippedBadges[bid]===tier) this._state.unequipBadge(bid);
    else this._state.equipBadge(bid,tier);
    this.setData({ showBadgeDetail: false });
    this._refresh();
  },

  onCBSlotTap(e) {
    const ai=parseInt(e.currentTarget.dataset.ai);
    const si=parseInt(e.currentTarget.dataset.si);
    const appliedCount = (this._state._appliedCapBreakers[ai]||[]).length;
    if (si < appliedCount) {
      for (let i = appliedCount - 1; i >= si; i--) this._state.removeCapBreaker(ai);
    } else {
      const cbSeq = this._state.getCapBreakerSequence(ai);
      for (let i = appliedCount; i <= si; i++) {
        if (i < cbSeq.length) this._state.applyCapBreaker(ai);
      }
    }
    this._refresh();
  },

  toggleMore() { this.setData({ moreOpen: !this.data.moreOpen }); },

  openBadges() { this.setData({ showBadges: true, moreOpen: false }); },
  closeBadges() { this.setData({ showBadges: false }); },
  onBadgeSearch(e) {
    const q = e.detail.value;
    this.setData({ badgeSearchQuery: q, filteredBadgeGroups: this._filterBadgeGroups(this.data.allBadges, q) });
  },

  openMoves() { this.setData({ showMoves: true, moreOpen: false }); },
  closeMoves() { this.setData({ showMoves: false }); },
  selectAnimTab(e) {
    const idx = e.currentTarget.dataset.idx;
    this.setData({ selectedAnimTab: idx, filteredAnimGroups: this._filterAnimGroups(this.data.animTabs, idx, this.data.moveSearchQuery) });
  },
  onMoveSearch(e) {
    const q = e.detail.value;
    this.setData({ moveSearchQuery: q, filteredAnimGroups: this._filterAnimGroups(this.data.animTabs, this.data.selectedAnimTab, q) });
  },
  toggleAnimGroup(e) {
    const gid = e.currentTarget.dataset.gid;
    const groups = this.data.filteredAnimGroups.map(g => {
      if (g.id === gid) g.expanded = !g.expanded;
      return g;
    });
    this.setData({ filteredAnimGroups: groups });
  },
  onAnimTap(e) {
    const id = e.currentTarget.dataset.id;
    wx.showToast({ title: id, icon: 'none' });
  },

  openMyB() {
    const builds = this._storage ? this._storage.builds.map(b => ({
      ...b, posLabel: POSITION_LABELS[b.position]||'PG',
      heightDisplay: `${Math.floor(b.heightInches/12)}'${b.heightInches%12}"`,
    })) : [];
    this.setData({ showMyB: true, moreOpen: false, savedBuilds: builds });
  },
  closeMyB() { this.setData({ showMyB: false }); },

  saveBuild() {
    if (!this._state || !this._storage) return;
    this._storage.saveBuild(this._state);
    this.setData({ moreOpen: false });
    wx.showToast({ title: 'Build saved', icon: 'success' });
  },

  loadBuild(e) {
    const id = e.currentTarget.dataset.id;
    const build = this._storage.getBuild(id);
    if (!build) return;
    this._storage.applyBuild(build, this._state);
    this.setData({ showMyB: false });
    this._refresh();
  },

  deleteBuild(e) {
    const id = e.currentTarget.dataset.id;
    wx.showModal({ title: 'Confirm', content: 'Delete?', success: res => {
      if (res.confirm) { this._storage.deleteBuild(id); this.openMyB(); }
    }});
  },

  // Add Goal Dialog
  openAddGoal() {
    this.setData({ showAddGoal: true, goalTabIndex: 0, goalSearchQuery: '', goalSelectedId: null, goalSelectedAttrIndex: -1, goalDialogError: '' });
    this._refreshGoalFilters();
  },
  closeAddGoal() { this.setData({ showAddGoal: false }); },
  switchGoalTab(e) { this.setData({ goalTabIndex: e.currentTarget.dataset.idx, goalSelectedId: null, goalSelectedAttrIndex: -1, goalSearchQuery: '', goalDialogError: '' }); this._refreshGoalFilters(); },
  onGoalSearch(e) { this.setData({ goalSearchQuery: e.detail.value }); this._refreshGoalFilters(); },
  toggleTierDropdown() { this.setData({ tierDropdownOpen: !this.data.tierDropdownOpen }); },
  selectTier(e) { this.setData({ selectedTier: parseInt(e.currentTarget.dataset.code), selectedTierLabel: e.currentTarget.dataset.label, tierDropdownOpen: false }); },
  selectGoalBadge(e) { this.setData({ goalSelectedId: parseInt(e.currentTarget.dataset.id), goalDialogError: '' }); },
  selectGoalMove(e) { this.setData({ goalSelectedId: parseInt(e.currentTarget.dataset.id), goalDialogError: '' }); },
  selectGoalAttr(e) { this.setData({ goalSelectedAttrIndex: parseInt(e.currentTarget.dataset.ai), goalDialogError: '' }); },
  onGoalTargetInput(e) { this.setData({ goalTargetValue: parseInt(e.detail.value) || 25 }); },

  _refreshGoalFilters() {
    const q = this.data.goalSearchQuery.toLowerCase();
    const defs = Array.isArray(this._loader.definitions) ? this._loader.definitions : [];
    const filteredBadges = defs.filter(d => !q || (d.displayName||d.name||'').toLowerCase().includes(q)).map(d => ({
      badgeId: d.badge, name: d.displayName||d.name||('Badge '+d.badge),
      discColor: DISCIPLINE_COLORS[d.discipline||1]||'#B09B74', discName: DISC_NAMES[d.discipline||1]||'',
    }));
    const filteredGoalAttrs = [];
    for (let i = 0; i < 21; i++) {
      if (!this._state._goalActive.has(i)) {
        const name = t(ATTRIBUTE_KEYS[i])||ATTR_EN[i];
        if (!q || name.toLowerCase().includes(q)) {
          const disc = Object.keys(DISCIPLINE_ATTRS).find(d=>DISCIPLINE_ATTRS[d].includes(i))||1;
          filteredGoalAttrs.push({ index: i, name, value: this._state.ratings[i], cap: this._state._physicalCaps[i], color: DISCIPLINE_COLORS[disc]||'#B09B74' });
        }
      }
    }
    this.setData({ filteredBadges, filteredGoalAttrs });
  },

  onGoalAdd() {
    const tab = this.data.goalTabIndex;
    if (tab === 0) {
      if (!this.data.goalSelectedId) { this.setData({ goalDialogError: 'Please select a badge' }); return; }
      if (!this.data.selectedTier) { this.setData({ goalDialogError: 'Please select a tier' }); return; }
      const def = this._loader.definitions.find(d => d.badge === this.data.goalSelectedId);
      if (!def) return;
      const reqs = [];
      const tierReqs = this._loader.tierRequirements ? this._loader.tierRequirements.filter(r => r.badge === def.badge && r.tier === BADGE_TIER_KEYS[this.data.selectedTier]) : [];
      for (const tr of tierReqs) {
        for (const r of (tr.requirements||[])) {
          reqs.push({ attributeIndex: r.attribute, minimum: r.minimum, attributeName: t(ATTRIBUTE_KEYS[r.attribute])||ATTR_EN[r.attribute] });
        }
      }
      this._state.addGoalBadge({ badgeId: def.badge, badgeName: def.displayName||def.name, tier: this.data.selectedTier, attributeRequirements: reqs });
    } else if (tab === 1) {
      if (!this.data.goalSelectedId) { this.setData({ goalDialogError: 'Please select a move' }); return; }
      this._state.addGoalMove({ id: this.data.goalSelectedId, name: 'Move ' + this.data.goalSelectedId });
    } else {
      if (this.data.goalSelectedAttrIndex < 0) { this.setData({ goalDialogError: 'Please select an attribute' }); return; }
      this._state.setGoalAttribute(this.data.goalSelectedAttrIndex, this.data.goalTargetValue);
    }
    this.setData({ showAddGoal: false });
    this._refresh();
  },

  toggleLocale() {
    const nl = app.toggleLocale();
    this.setData({ locale: nl, moreOpen: false });
    this._refresh();
  },
});
