const app = getApp();
const { t } = require('../../i18n/index');
const { POSITION_LABELS } = require('../../models/enums');
const { BuildStorageService } = require('../../services/build-storage');

Page({
  data: { builds: [], positions: ['PG','SG','SF','PF','C'] },
  _storage: null,

  onLoad() {
    this._storage = new BuildStorageService();
    this._storage.loadBuilds();
    this._refresh();
  },
  onShow() { if(this._storage){this._storage.loadBuilds();this._refresh();} },

  _refresh() {
    const builds = this._storage.builds.map(b => ({
      ...b, posLabel: POSITION_LABELS[b.position]||'PG',
      heightDisplay: `${Math.floor(b.heightInches/12)}'${b.heightInches%12}"`,
    }));
    this.setData({ builds });
  },

  loadBuild(e) {
    const id = e.currentTarget.dataset.id;
    wx.navigateTo({ url: '/pages/index/index?loadBuildId=' + id });
  },

  deleteBuild(e) {
    const id = e.currentTarget.dataset.id;
    wx.showModal({title:'Confirm',content:'Delete?',success:res=>{
      if(res.confirm){this._storage.deleteBuild(id);this._refresh();}
    }});
  },

  goBack() { wx.navigateBack(); },
});
