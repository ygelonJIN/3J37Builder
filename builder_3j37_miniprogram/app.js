const { DatasetLoader } = require('./services/dataset-loader');
const { BuilderState } = require('./services/builder-state');
const { CapBreakerEngine } = require('./services/cap-breaker-engine');
const { TuningParser } = require('./services/tuning-parser');
const { BuildStorageService } = require('./services/build-storage');
const { t, setLocale, getLocale } = require('./i18n/index');

App({
  globalData: {
    locale: 'zh_CN',
    datasetLoader: null,
    builderState: null,
    capBreakerEngine: null,
    tuningParser: null,
    buildStorage: null,
    essentialLoaded: false,
    heavyLoaded: false,
  },

  onLaunch() {
    this.globalData.datasetLoader = new DatasetLoader();
    this.globalData.capBreakerEngine = new CapBreakerEngine();
    this.globalData.tuningParser = new TuningParser();
    this.globalData.buildStorage = new BuildStorageService();
    
    const savedLocale = wx.getStorageSync('selected_locale') || 'zh_CN';
    this.globalData.locale = savedLocale;
    setLocale(savedLocale);
    
    this.globalData.buildStorage.loadBuilds();
  },

  toggleLocale() {
    const newLocale = this.globalData.locale === 'zh_CN' ? 'en_US' : 'zh_CN';
    this.globalData.locale = newLocale;
    setLocale(newLocale);
    wx.setStorageSync('selected_locale', newLocale);
    return newLocale;
  },

  t(key, params) { return t(key, params); }
});
