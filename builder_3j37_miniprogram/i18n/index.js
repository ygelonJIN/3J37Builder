const zh = require('./zh');
const en = require('./en');

let currentLocale = 'zh_CN';

const translations = { zh_CN: zh, en_US: en };

function t(key, params) {
  let translation = translations[currentLocale]?.[key] || translations['en_US']?.[key] || key;
  
  // 支持参数替换，如 {count}、{item} 等
  if (params) {
    Object.keys(params).forEach(param => {
      translation = translation.replace(new RegExp(`\\{${param}\\}`, 'g'), params[param]);
    });
  }
  
  return translation;
}

function setLocale(locale) {
  currentLocale = locale;
}

function getLocale() {
  return currentLocale;
}

module.exports = { t, setLocale, getLocale };
