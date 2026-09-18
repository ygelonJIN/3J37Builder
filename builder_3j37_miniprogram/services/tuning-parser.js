/**
 * NBA 2K27 Tuning 解析器
 * 
 * 解析 progression_attributes.txt 中的键值对数据。
 * 提供计算 OVR 和属性上限的方法。
 * 
 * 核心功能：
 *   - 解析 key,value 格式的 tuning 数据
 *   - 计算球员 Overall Rating (OVR)
 *   - 计算属性物理上限（基于身体参数）
 *   - 支持位置、身高、体重、臂展的影响
 */

// ─── 属性索引映射 ─────────────────────────────────────────────────────────────

const ATTRIBUTE_NAMES = [
  'ShotClose',        // 0: 近距离投篮
  'DrivingLayup',     // 1: 突破上篮
  'DrivingDunk',      // 2: 突破扣篮
  'StandingDunk',     // 3: 原地扣篮
  'PostControl',      // 4: 背身控制
  'ShotMidrange',     // 5: 中距离投篮
  'ShotThree',        // 6: 三分投篮
  'ShotFreeThrow',    // 7: 罚球
  'PassAccuracy',     // 8: 传球准确性
  'BallControl',      // 9: 控球
  'SpeedWithBall',    // 10: 运球速度
  'InteriorDefense',  // 11: 内线防守
  'PerimeterDefense', // 12: 外线防守
  'Steal',            // 13: 抢断
  'Block',            // 14: 盖帽
  'ReboundOffense',   // 15: 进攻篮板
  'ReboundDefense',   // 16: 防守篮板
  'Speed',            // 17: 速度
  'Agility',          // 18: 敏捷
  'Strength',         // 19: 力量
  'Vertical',         // 20: 弹跳
];

const POSITION_NAMES = ['POINT_GUARD', 'SHOOTING_GUARD', 'SMALL_FORWARD', 'POWER_FORWARD', 'CENTER'];
const POSITION_INDEX = { 'PG': 0, 'SG': 1, 'SF': 2, 'PF': 3, 'C': 4 };

// ─── TuningParser 类 ─────────────────────────────────────────────────────────

class TuningParser {
  constructor() {
    /** @private */ this._keys = new Map();  // 所有解析的键值对
    /** @private */ this._parsed = false;
    
    // 缓存的乘数表
    /** @private */ this._weightMultipliers = null;  // 身高 → 体重 → 属性乘数
    /** @private */ this._wingspanMultipliers = null; // 身高 → 臂展 → 属性乘数
    /** @private */ this._heightMultipliers = null;   // 身高 → 属性乘数
    /** @private */ this._positionMultipliers = null; // 位置 → 属性乘数
    /** @private */ this._archetypeData = null;       // 原型数据
  }

  // ── 属性 ──────────────────────────────────────────────────────────────────

  get isParsed() { return this._parsed; }
  get keyCount() { return this._keys.size; }

  // ── 解析方法 ──────────────────────────────────────────────────────────────

  /**
   * 解析 tuning 文本内容
   * @param {string} content - progression_attributes.txt 的内容
   */
  parse(content) {
    if (!content) {
      console.error('[TuningParser] parse: content is empty');
      return;
    }

    const lines = content.split('\n');
    let parsedCount = 0;

    for (const line of lines) {
      const trimmed = line.trim();
      
      // 跳过空行和注释
      if (!trimmed || trimmed.startsWith('//')) continue;
      
      // 跳过 DataPath 头
      if (trimmed.startsWith('DataPath|')) continue;
      
      // 解析 key,value 格式
      const commaIndex = trimmed.indexOf(',');
      if (commaIndex === -1) continue;
      
      const key = trimmed.substring(0, commaIndex).trim();
      const valueStr = trimmed.substring(commaIndex + 1).trim();
      
      // 尝试解析为数字
      let value;
      if (valueStr === 'true') {
        value = true;
      } else if (valueStr === 'false') {
        value = false;
      } else {
        const num = parseFloat(valueStr);
        value = isNaN(num) ? valueStr : num;
      }
      
      this._keys.set(key, value);
      parsedCount++;
    }

    this._parsed = true;
    console.log(`[TuningParser] Parsed ${parsedCount} keys`);
    
    // 预处理乘数表
    this._preprocessMultipliers();
  }

  /**
   * 获取 tuning 值
   * @param {string} key - 键名
   * @param {*} defaultValue - 默认值
   * @returns {*} 值
   */
  get(key, defaultValue = undefined) {
    return this._keys.has(key) ? this._keys.get(key) : defaultValue;
  }

  /**
   * 检查键是否存在
   * @param {string} key - 键名
   * @returns {boolean}
   */
  has(key) {
    return this._keys.has(key);
  }

  /**
   * 获取所有匹配前缀的键值对
   * @param {string} prefix - 键前缀
   * @returns {Map<string, *>}
   */
  getByPrefix(prefix) {
    const result = new Map();
    for (const [key, value] of this._keys) {
      if (key.startsWith(prefix)) {
        result.set(key, value);
      }
    }
    return result;
  }

  // ── 预处理乘数表 ──────────────────────────────────────────────────────────

  /**
   * 预处理身体乘数表，便于快速查询
   */
  _preprocessMultipliers() {
    // 解析体重乘数
    this._weightMultipliers = this._parseMultiplierTable('PlayerRestrictions[NBA].WeightMultiplier');
    
    // 解析臂展乘数
    this._wingspanMultipliers = this._parseMultiplierTable('PlayerRestrictions[NBA].WingspanMultiplier');
    
    // 解析位置乘数
    this._positionMultipliers = this._parsePositionMultipliers();
    
    // 解析原型数据
    this._archetypeData = this._parseArchetypeData();
    
    console.log('[TuningParser] Multiplier tables preprocessed');
  }

  /**
   * 解析乘数表（体重/臂展）
   * @param {string} prefix - 键前缀
   * @returns {Map<number, Map<number, Map<string, number>>>}
   */
  _parseMultiplierTable(prefix) {
    // 结构: heightIndex → entryIndex → attribute → multiplier
    const table = new Map();
    
    // 找到所有条目
    const entryPattern = new RegExp(`^${prefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\[(\\d+)\\]\\.`);
    
    for (const [key, value] of this._keys) {
      const match = key.match(entryPattern);
      if (!match) continue;
      
      const entryIndex = parseInt(match[1]);
      
      // 获取身高和体重/臂展
      const heightKey = `${prefix}[${entryIndex}].HeightInInches`;
      const weightKey = `${prefix}[${entryIndex}].Weight`;
      const wingspanKey = `${prefix}[${entryIndex}].WingspanInInches`;
      
      const height = this.get(heightKey);
      const weight = this.get(weightKey);
      const wingspan = this.get(wingspanKey);
      
      if (height === undefined) continue;
      
      // 解析属性乘数
      const multipliers = new Map();
      for (const attr of ATTRIBUTE_NAMES) {
        const attrKey = `${prefix}[${entryIndex}].Multiplier[${attr}]`;
        const attrValue = this.get(attrKey);
        if (attrValue !== undefined) {
          multipliers.set(attr, attrValue);
        }
      }
      
      // 存储到表中
      if (!table.has(height)) {
        table.set(height, new Map());
      }
      
      const bodyKey = weight !== undefined ? weight : wingspan;
      if (bodyKey !== undefined) {
        table.get(height).set(bodyKey, multipliers);
      }
    }
    
    return table;
  }

  /**
   * 解析位置乘数
   * @returns {Map<string, Map<string, number>>}
   */
  _parsePositionMultipliers() {
    const multipliers = new Map();
    
    for (const pos of POSITION_NAMES) {
      const posMultipliers = new Map();
      
      for (const attr of ATTRIBUTE_NAMES) {
        const key = `PerPosition[${pos}].MultiplierToRelativeAttributeImportanceForPricing[${attr}]`;
        const value = this.get(key);
        if (value !== undefined) {
          posMultipliers.set(attr, value);
        }
      }
      
      multipliers.set(pos, posMultipliers);
    }
    
    return multipliers;
  }

  /**
   * 解析原型数据
   * @returns {Map<string, Map<string, number[]>>}
   */
  _parseArchetypeData() {
    const archetypes = new Map();
    
    // 找到所有原型
    const archetypePattern = /^DataPerArchetype\[([^\]]+)\]\.MinMaxValuePerAttribute\[([^\]]+)\]\[(\d+)\]$/;
    
    for (const [key, value] of this._keys) {
      const match = key.match(archetypePattern);
      if (!match) continue;
      
      const [, archetype, attr, index] = match;
      
      if (!archetypes.has(archetype)) {
        archetypes.set(archetype, new Map());
      }
      
      const attrData = archetypes.get(archetype);
      if (!attrData.has(attr)) {
        attrData.set(attr, [0, 0]);
      }
      
      attrData.get(attr)[parseInt(index)] = value;
    }
    
    return archetypes;
  }

  // ── 属性上限计算 ──────────────────────────────────────────────────────────

  /**
   * 计算属性物理上限
   * 
   * @param {number} positionIndex - 位置索引（0-4）
   * @param {number} heightInches - 身高（英寸，69-88）
   * @param {number} weightLb - 体重（磅）
   * @param {number} wingspanInches - 臂展（英寸）
   * @returns {number[]} 21个属性的物理上限数组
   */
  computeAttributeCaps(positionIndex, heightInches, weightLb, wingspanInches) {
    if (!this._parsed) {
      console.error('[TuningParser] computeAttributeCaps: Not parsed');
      return new Array(21).fill(99);
    }

    const caps = new Array(21);
    const heightIndex = Math.round(heightInches) - 69; // 69英寸 = index 0
    
    for (let i = 0; i < 21; i++) {
      const attrName = ATTRIBUTE_NAMES[i];
      let cap = 99; // 默认上限
      
      // 应用体重乘数
      const weightMultiplier = this._getWeightMultiplier(heightIndex, weightLb, attrName);
      
      // 应用臂展乘数
      const wingspanMultiplier = this._getWingspanMultiplier(heightIndex, wingspanInches, attrName);
      
      // 计算最终上限: cap = 99 * weightMultiplier * wingspanMultiplier
      cap = Math.round(99 * weightMultiplier * wingspanMultiplier);
      
      // 确保在合理范围内
      caps[i] = Math.max(25, Math.min(99, cap));
    }
    
    return caps;
  }

  /**
   * 获取体重乘数
   * @param {number} heightIndex - 身高索引
   * @param {number} weight - 体重
   * @param {string} attrName - 属性名
   * @returns {number} 乘数
   */
  _getWeightMultiplier(heightIndex, weight, attrName) {
    if (!this._weightMultipliers || !this._weightMultipliers.has(heightIndex + 69)) {
      return 1.0;
    }
    
    const heightTable = this._weightMultipliers.get(heightIndex + 69);
    
    // 找到最接近的体重条目
    let bestWeight = null;
    let bestDiff = Infinity;
    
    for (const [w] of heightTable) {
      const diff = Math.abs(w - weight);
      if (diff < bestDiff) {
        bestDiff = diff;
        bestWeight = w;
      }
    }
    
    if (bestWeight === null) return 1.0;
    
    const multipliers = heightTable.get(bestWeight);
    return multipliers.get(attrName) || 1.0;
  }

  /**
   * 获取臂展乘数
   * @param {number} heightIndex - 身高索引
   * @param {number} wingspan - 臂展
   * @param {string} attrName - 属性名
   * @returns {number} 乘数
   */
  _getWingspanMultiplier(heightIndex, wingspan, attrName) {
    if (!this._wingspanMultipliers || !this._wingspanMultipliers.has(heightIndex + 69)) {
      return 1.0;
    }
    
    const heightTable = this._wingspanMultipliers.get(heightIndex + 69);
    
    // 找到最接近的臂展条目
    let bestWingspan = null;
    let bestDiff = Infinity;
    
    for (const [w] of heightTable) {
      const diff = Math.abs(w - wingspan);
      if (diff < bestDiff) {
        bestDiff = diff;
        bestWingspan = w;
      }
    }
    
    if (bestWingspan === null) return 1.0;
    
    const multipliers = heightTable.get(bestWingspan);
    return multipliers.get(attrName) || 1.0;
  }

  // ── OVR 计算 ──────────────────────────────────────────────────────────────

  /**
   * 计算 Overall Rating (OVR)
   * 
   * 使用 2K27 的详细 OVR 计算方法：
   * 1. 找到最匹配的原型（archetype）
   * 2. 计算每个属性的加权贡献
   * 3. 应用位置乘数
   * 4. 计算最终 OVR
   * 
   * @param {number} positionIndex - 位置索引（0-4）
   * @param {number} heightInches - 身高（英寸）
   * @param {number[]} ratings - 21个属性值数组
   * @returns {number} OVR（浮点数）
   */
  computeOvr(positionIndex, heightInches, ratings) {
    if (!this._parsed || !ratings || ratings.length !== 21) {
      return 0;
    }

    const positionName = POSITION_NAMES[positionIndex] || 'POINT_GUARD';
    
    // 找到最佳匹配的原型
    const bestArchetype = this._findBestArchetype(positionName, ratings);
    if (!bestArchetype) {
      return this._computeSimpleOvr(positionName, ratings);
    }
    
    // 使用原型计算 OVR
    return this._computeArchetypeOvr(positionName, bestArchetype, ratings);
  }

  /**
   * 找到最匹配的原型
   * @param {string} positionName - 位置名
   * @param {number[]} ratings - 属性值数组
   * @returns {string|null} 原型名
   */
  _findBestArchetype(positionName, ratings) {
    if (!this._archetypeData) return null;
    
    let bestArchetype = null;
    let bestScore = -Infinity;
    
    for (const [archetype, attrData] of this._archetypeData) {
      let score = 0;
      let matchCount = 0;
      
      for (let i = 0; i < 21; i++) {
        const attrName = ATTRIBUTE_NAMES[i];
        const range = attrData.get(attrName);
        if (!range) continue;
        
        const [min, max] = range;
        const rating = ratings[i];
        
        // 计算属性在原型范围内的匹配度
        if (rating >= min && rating <= max) {
          score += 1.0; // 完全匹配
        } else {
          // 部分匹配（越接近越好）
          const distance = rating < min ? min - rating : rating - max;
          score += Math.max(0, 1.0 - distance / 20);
        }
        matchCount++;
      }
      
      // 归一化分数
      if (matchCount > 0) {
        score /= matchCount;
      }
      
      if (score > bestScore) {
        bestScore = score;
        bestArchetype = archetype;
      }
    }
    
    return bestArchetype;
  }

  /**
   * 使用原型计算 OVR
   * @param {string} positionName - 位置名
   * @param {string} archetype - 原型名
   * @param {number[]} ratings - 属性值数组
   * @returns {number} OVR
   */
  _computeArchetypeOvr(positionName, archetype, ratings) {
    const attrData = this._archetypeData.get(archetype);
    if (!attrData) return 0;
    
    let totalWeight = 0;
    let weightedSum = 0;
    
    for (let i = 0; i < 21; i++) {
      const attrName = ATTRIBUTE_NAMES[i];
      const range = attrData.get(attrName);
      if (!range) continue;
      
      const [min, max] = range;
      const rating = ratings[i];
      
      // 获取位置乘数
      const posMultiplier = this._getPositionMultiplier(positionName, attrName);
      
      // 计算属性在原型范围内的位置（0-1）
      const rangeSize = max - min;
      let normalizedRating;
      if (rangeSize > 0) {
        normalizedRating = (rating - min) / rangeSize;
      } else {
        normalizedRating = rating >= min ? 1.0 : 0.0;
      }
      
      // 限制在 0-1 范围内
      normalizedRating = Math.max(0, Math.min(1, normalizedRating));
      
      // 加权累加
      const weight = posMultiplier;
      weightedSum += normalizedRating * weight;
      totalWeight += weight;
    }
    
    // 计算 OVR（缩放到 0-99 范围）
    if (totalWeight > 0) {
      const ovr = (weightedSum / totalWeight) * 99;
      return Math.max(0, Math.min(99, ovr));
    }
    
    return 0;
  }

  /**
   * 简单 OVR 计算（无原型匹配时的备用方法）
   * @param {string} positionName - 位置名
   * @param {number[]} ratings - 属性值数组
   * @returns {number} OVR
   */
  _computeSimpleOvr(positionName, ratings) {
    let totalWeight = 0;
    let weightedSum = 0;
    
    for (let i = 0; i < 21; i++) {
      const attrName = ATTRIBUTE_NAMES[i];
      const rating = ratings[i];
      
      // 获取位置乘数
      const posMultiplier = this._getPositionMultiplier(positionName, attrName);
      
      // 简单加权平均
      weightedSum += rating * posMultiplier;
      totalWeight += posMultiplier;
    }
    
    if (totalWeight > 0) {
      return weightedSum / totalWeight;
    }
    
    return 0;
  }

  /**
   * 获取位置乘数
   * @param {string} positionName - 位置名
   * @param {string} attrName - 属性名
   * @returns {number} 乘数
   */
  _getPositionMultiplier(positionName, attrName) {
    if (!this._positionMultipliers) return 1.0;
    
    const posMultipliers = this._positionMultipliers.get(positionName);
    if (!posMultipliers) return 1.0;
    
    return posMultipliers.get(attrName) || 1.0;
  }

  // ── 调试方法 ──────────────────────────────────────────────────────────────

  /**
   * 获取所有键（用于调试）
   * @returns {string[]}
   */
  getAllKeys() {
    return Array.from(this._keys.keys());
  }

  /**
   * 导出所有数据（用于调试）
   * @returns {Object}
   */
  exportData() {
    const data = {};
    for (const [key, value] of this._keys) {
      data[key] = value;
    }
    return data;
  }
}

// ─── 导出 ─────────────────────────────────────────────────────────────────────

module.exports = {
  TuningParser,
  ATTRIBUTE_NAMES,
  POSITION_NAMES,
  POSITION_INDEX,
};
