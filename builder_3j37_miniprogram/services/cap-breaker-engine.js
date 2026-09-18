/**
 * NBA 2K27 破帽器计算引擎 (Cap Breaker Engine)
 * 完整从 Dart 版本翻译，保留所有功能
 *
 * 依赖模型数据:
 *   - weights: Float64Array / Array, 长度 = 21 × 300 (21属性 × 300权重条目)
 *     权重索引: (heightIndex * 15 + slot) * 21 + attrIndex
 *     其中 heightIndex ∈ [0,19], slot ∈ [0,14], attrIndex ∈ [0,20]
 *   - curves: Float64Array / Array, 长度 = 21 × 100 (21属性 × 100曲线值)
 *     曲线索引: attrIndex * 100 + valueIndex
 *   - overallScale: 整体 OVR 缩放因子
 */

// ─── 核心常量 ─────────────────────────────────────────────────────────────────

const CAP_BREAKER_ATTRIBUTES = [
  { id: 'closeShot',        name: '近距离投篮', category: 'finishing',   weight: 1.0,  index: 0 },
  { id: 'layup',            name: '突破上篮',   category: 'finishing',   weight: 1.15, index: 1 },
  { id: 'drivingDunk',      name: '突破扣篮',   category: 'finishing',   weight: 1.35, index: 2 },
  { id: 'standingDunk',     name: '原地扣篮',   category: 'finishing',   weight: 1.15, index: 3 },
  { id: 'postControl',      name: '背身控制',   category: 'finishing',   weight: 1.0,  index: 4 },
  { id: 'midRange',         name: '中距离投篮', category: 'shooting',    weight: 1.1,  index: 5 },
  { id: 'threePoint',       name: '三分投篮',   category: 'shooting',    weight: 1.4,  index: 6 },
  { id: 'freeThrow',        name: '罚球',       category: 'shooting',    weight: 0.65, index: 7 },
  { id: 'passAccuracy',     name: '传球准确性', category: 'playmaking',  weight: 1.0,  index: 8 },
  { id: 'ballHandle',       name: '控球',       category: 'playmaking',  weight: 1.25, index: 9 },
  { id: 'speedWithBall',    name: '运球速度',   category: 'playmaking',  weight: 1.2,  index: 10 },
  { id: 'interiorDefense',  name: '内线防守',   category: 'defense',     weight: 1.05, index: 11 },
  { id: 'perimeterDefense', name: '外线防守',   category: 'defense',     weight: 1.25, index: 12 },
  { id: 'steal',            name: '抢断',       category: 'defense',     weight: 1.2,  index: 13 },
  { id: 'block',            name: '盖帽',       category: 'defense',     weight: 1.1,  index: 14 },
  { id: 'offensiveRebound', name: '进攻篮板',   category: 'rebounding',  weight: 0.95, index: 15 },
  { id: 'defensiveRebound', name: '防守篮板',   category: 'rebounding',  weight: 1.0,  index: 16 },
  { id: 'speed',            name: '速度',       category: 'physical',    weight: 1.25, index: 17 },
  { id: 'agility',          name: '敏捷',       category: 'physical',    weight: 1.05, index: 18 },
  { id: 'strength',         name: '力量',       category: 'physical',    weight: 1.0,  index: 19 },
  { id: 'vertical',         name: '弹跳',       category: 'physical',    weight: 0.95, index: 20 },
];

const CAP_BREAKER_CATEGORIES = [
  { id: 'finishing',   name: '终结', color: '#00a4ff' },
  { id: 'shooting',    name: '投射', color: '#31de74' },
  { id: 'playmaking',  name: '组织', color: '#FFc600' },
  { id: 'defense',     name: '防守', color: '#FF6466' },
  { id: 'rebounding',  name: '篮板', color: '#b57eff' },
  { id: 'physical',    name: '身体', color: '#c4a882' },
];

// 索引快速查找表（避免重复遍历）
const _ATTR_BY_ID    = {};
const _ATTR_BY_INDEX = new Array(21);
for (const a of CAP_BREAKER_ATTRIBUTES) {
  _ATTR_BY_ID[a.id]    = a;
  _ATTR_BY_INDEX[a.index] = a;
}

const _CATEGORY_BY_ID = {};
for (const c of CAP_BREAKER_CATEGORIES) {
  _CATEGORY_BY_ID[c.id] = c;
}

// ─── 工具函数 ─────────────────────────────────────────────────────────────────

/**
 * 四舍六入五成双（银行家舍入法 / Banker's Rounding）
 * - 小数部分 < 0.5 → 向下
 * - 小数部分 > 0.5 → 向上
 * - 恰好 0.5 时，整数部分为偶数则向下，奇数则向上
 * @param {number} x
 * @returns {number}
 */
function roundHalfEven(x) {
  const floor = Math.floor(x);
  const frac  = x - floor;
  if (Math.abs(frac - 0.5) < 1e-12) {
    return floor % 2 === 0 ? floor : floor + 1;
  }
  return Math.round(x);
}

function clamp(v, lo, hi) {
  return v < lo ? lo : v > hi ? hi : v;
}

// ─── CapBreakerEngine ────────────────────────────────────────────────────────

class CapBreakerEngine {
  constructor() {
    /** @private */ this._weights = null;      // 模型权重 数组/TypedArray
    /** @private */ this._curves  = null;      // 模型曲线 数组/TypedArray
    /** @private */ this._overallScale = 1.0;  // 整体 OVR 缩放
  }

  // ── 数据加载 ──────────────────────────────────────────────────────────────

  /**
   * 加载模型数据
   * @param {Array<number>|Float64Array} weights - 长度 6300 (21×300)
   * @param {Array<number>|Float64Array} curves  - 长度 2100 (21×100)
   * @param {number} [overallScale=1.0]
   */
  loadModelData(weights, curves, overallScale) {
    if (!weights || weights.length < 21 * 300) {
      throw new Error('weights 数据不足，需要至少 6300 个元素 (21×300)');
    }
    if (!curves || curves.length < 21 * 100) {
      throw new Error('curves 数据不足，需要至少 2100 个元素 (21×100)');
    }
    this._weights = weights;
    this._curves  = curves;
    this._overallScale = (typeof overallScale === 'number' && isFinite(overallScale))
      ? overallScale
      : 1.0;
  }

  /** 模型数据是否已加载 */
  get hasModelData() {
    return this._weights !== null && this._curves !== null;
  }

  // ── 静态查询 ──────────────────────────────────────────────────────────────

  /** 根据属性 ID 获取索引，不存在返回 -1 */
  static getAttributeIndex(attributeId) {
    const a = _ATTR_BY_ID[attributeId];
    return a ? a.index : -1;
  }

  /** 根据索引获取属性 ID，不存在返回 null */
  static getAttributeId(index) {
    const a = _ATTR_BY_INDEX[index];
    return a ? a.id : null;
  }

  /** 根据索引获取属性中文名，不存在返回 null */
  static getAttributeName(index) {
    const a = _ATTR_BY_INDEX[index];
    return a ? a.name : null;
  }

  /** 根据属性 ID 获取完整属性对象，不存在返回 null */
  static getAttribute(attributeId) {
    return _ATTR_BY_ID[attributeId] || null;
  }

  /** 根据分类 ID 获取分类对象 */
  static getCategory(categoryId) {
    return _CATEGORY_BY_ID[categoryId] || null;
  }

  /** 获取所有属性 */
  static getAttributes() {
    return CAP_BREAKER_ATTRIBUTES;
  }

  /** 获取所有分类 */
  static getCategories() {
    return CAP_BREAKER_CATEGORIES;
  }

  // ── 内部方法 ──────────────────────────────────────────────────────────────

  /**
   * 四舍六入五成双（实例方法，委托给模块级函数）
   * @param {number} x
   * @returns {number}
   */
  _roundHalfEven(x) {
    return roundHalfEven(x);
  }

  /**
   * 计算某个 archetype slot 的加权 OVR
   * OVR = Σ(value[attr] × attr_weight × model_weight) / Σ(attr_weight × model_weight)
   *
   * @param {number} slot        - archetype slot 索引 [0, 14]
   * @param {number} heightIndex - 身高索引 [0, 19]
   * @param {Map<string,number>|Object} values - 21 个属性值 {attrId: value}
   * @returns {number}
   */
  _archetypeOVR(slot, heightIndex, values) {
    if (!this.hasModelData) return 0;

    let totalWeightedValue = 0;
    let totalWeight        = 0;

    for (let attrIdx = 0; attrIdx < 21; attrIdx++) {
      // 模型权重
      const modelW = this._weights[(heightIndex * 15 + slot) * 21 + attrIdx] || 0;
      // 属性自身权重
      const attrW  = _ATTR_BY_INDEX[attrIdx].weight || 1.0;
      // 组合权重
      const w = modelW * attrW;

      // 属性值：支持 Map 或普通 Object
      const attrId = _ATTR_BY_INDEX[attrIdx].id;
      let v = 0;
      if (values instanceof Map) {
        v = values.get(attrId) || 0;
      } else if (values && typeof values === 'object') {
        v = values[attrId] || 0;
      }

      totalWeightedValue += v * w;
      totalWeight        += w;
    }

    if (totalWeight <= 0) return 0;
    return (totalWeightedValue / totalWeight) * this._overallScale;
  }

  // ── 核心算法 ──────────────────────────────────────────────────────────────

  /**
   * 计算破帽器链式增益 (Cap Breaker Chained Gains)
   *
   * 算法流程 (从 Dart ce 函数翻译):
   * 1. 根据身高计算 heightIndex: d = clamp(height - 69, 0, 19)
   * 2. 在 15 个 archetype slot 中找到最佳匹配（加权 OVR 最高）
   * 3. 获取该 slot 的 21 个权重: weights[(d*15+slot)*21 + attrIdx]
   * 4. 计算 maxWeight（21个权重中最大值）, attrWeight（当前属性权重）
   * 5. relativeWeight = (maxWeight - attrWeight) / maxWeight
   * 6. 逐档计算增益:
   *    curveIdx = 15 + floor((25 - A) * 14 / 74)
   *    gain = min(remaining, max(1, roundHalfEven(curve[curveIdx] * relativeWeight)))
   *    其中 A 为当前累计值
   *
   * @param {number} attrIndex      - 属性索引 [0, 20]
   * @param {number} currentValue   - 属性当前值
   * @param {Map<string,number>|Object} values - 所有 21 个属性值
   * @param {Object} body           - 身体参数 { position, height, weight, wingspan }
   * @param {number[]} physicalCaps - 21 个属性的物理上限数组
   * @returns {Array<{tierIndex: number, gain: number, newValue: number, capBreakerCost: number}>}
   */
  getChainedGains(attrIndex, currentValue, values, body, physicalCaps) {
    if (!this.hasModelData) {
      throw new Error('CapBreakerEngine: 模型数据未加载，请先调用 loadModelData()');
    }
    if (attrIndex < 0 || attrIndex > 20) {
      throw new RangeError(`attrIndex 必须在 [0, 20] 范围内，当前值: ${attrIndex}`);
    }
    if (!physicalCaps || physicalCaps.length < 21) {
      throw new Error('physicalCaps 必须包含至少 21 个元素');
    }

    // ── Step 1: 身高索引 ──────────────────────────────────────────────────
    const height = (body && body.height) ? body.height : 72; // 默认 6'0"
    const d = clamp(Math.round(height) - 69, 0, 19);

    // ── Step 2: 找最佳 archetype slot ─────────────────────────────────────
    let bestSlot = 0;
    let bestOVR  = -Infinity;
    for (let slot = 0; slot < 15; slot++) {
      const ovr = this._archetypeOVR(slot, d, values);
      if (ovr > bestOVR) {
        bestOVR  = ovr;
        bestSlot = slot;
      }
    }

    // ── Step 3: 获取 21 个模型权重 ────────────────────────────────────────
    const baseWeightOffset = (d * 15 + bestSlot) * 21;
    const modelWeights = new Array(21);
    let maxWeight = -Infinity;
    for (let i = 0; i < 21; i++) {
      const w = this._weights[baseWeightOffset + i] || 0;
      modelWeights[i] = w;
      if (w > maxWeight) maxWeight = w;
    }

    // ── Step 4: 计算 relativeWeight ──────────────────────────────────────
    const attrWeight = modelWeights[attrIndex] || 0;
    const relativeWeight = maxWeight > 0
      ? (maxWeight - attrWeight) / maxWeight
      : 0;

    // ── Step 5: 逐档计算增益 ─────────────────────────────────────────────
    const cap = physicalCaps[attrIndex];
    const remaining = cap - currentValue;
    if (remaining <= 0) return [];

    const gains     = [];
    let A           = currentValue;   // 当前累计值
    let left        = remaining;      // 剩余可分配

    let tierIndex   = 0;

    while (left > 0) {
      // curveIdx: 基于剩余空间的曲线索引
      // A 越接近上限 → curveIdx 越小 → 增益越少
      const curveIdx = clamp(15 + Math.floor((25 - A) * 14 / 74), 0, 99);

      // 从曲线数组获取基础增益值
      const curveBase = this._curves[attrIndex * 100 + curveIdx] || 0;

      // 计算增益: roundHalfEven(curveBase * relativeWeight)，最小 1
      let gain = roundHalfEven(curveBase * relativeWeight);
      if (gain < 1) gain = 1;

      // 不超过剩余可分配
      if (gain > left) gain = left;

      const newValue = A + gain;

      gains.push({
        tierIndex:      tierIndex,
        gain:           gain,
        newValue:       newValue,
        capBreakerCost: 1,   // 每档消耗 1 点 cap breaker
      });

      A           = newValue;
      left        -= gain;
      tierIndex   += 1;

      // 安全阀：防止极端情况下的无限循环
      if (gain <= 0) break;
    }

    return gains;
  }

  /**
   * 批量计算多个属性的破帽器增益
   *
   * @param {number[]} attrIndices    - 属性索引数组
   * @param {Map<string,number>|Object} currentValues - 各属性当前值 {attrId: value}
   * @param {Map<string,number>|Object} values - 所有 21 个属性值
   * @param {Object} body             - 身体参数
   * @param {number[]} physicalCaps   - 物理上限数组
   * @returns {Map<number, Array>}    - {attrIndex: gains[]}
   */
  getBatchChainedGains(attrIndices, currentValues, values, body, physicalCaps) {
    const results = new Map();
    for (const idx of attrIndices) {
      const attrId = _ATTR_BY_INDEX[idx] ? _ATTR_BY_INDEX[idx].id : null;
      let currentValue = 0;
      if (attrId) {
        if (currentValues instanceof Map) {
          currentValue = currentValues.get(attrId) || 0;
        } else if (currentValues && typeof currentValues === 'object') {
          currentValue = currentValues[attrId] || 0;
        }
      }
      results.set(idx, this.getChainedGains(idx, currentValue, values, body, physicalCaps));
    }
    return results;
  }

  /**
   * 计算属性的 OVR 贡献
   *
   * @param {number} attrIndex
   * @param {number} value
   * @param {Map<string,number>|Object} values
   * @param {Object} body
   * @returns {number}
   */
  getAttributeOVRContribution(attrIndex, value, values, body) {
    if (!this.hasModelData) return 0;

    const height = (body && body.height) ? body.height : 72;
    const d = clamp(Math.round(height) - 69, 0, 19);

    // 找最佳 slot
    let bestSlot = 0;
    let bestOVR  = -Infinity;
    for (let slot = 0; slot < 15; slot++) {
      const ovr = this._archetypeOVR(slot, d, values);
      if (ovr > bestOVR) {
        bestOVR  = ovr;
        bestSlot = slot;
      }
    }

    const baseWeightOffset = (d * 15 + bestSlot) * 21;
    const modelW = this._weights[baseWeightOffset + attrIndex] || 0;
    const attrW  = _ATTR_BY_INDEX[attrIndex].weight || 1.0;

    return value * attrW * modelW;
  }
}

// ─── 导出 ─────────────────────────────────────────────────────────────────────

module.exports = {
  CapBreakerEngine,
  CAP_BREAKER_ATTRIBUTES,
  CAP_BREAKER_CATEGORIES,
};
