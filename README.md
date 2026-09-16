# 3J37 Builder — NBA 2K27 MyPLAYER 建模平台

## 项目概述

基于 NBA 2K27 官方数据集构建的跨平台 MyPLAYER 建模工具。使用 Flutter 开发，支持 iOS、Android 和 Web。

**核心功能：**
- 选择位置（PG/SG/SF/PF/C）、身高、体重、臂展
- 21 个属性加减按钮控制，每个有精确上限（来自 tuning 数据）
- 属性联动约束（提高/降低一个属性会联动相关属性）
- OVR 总评计算（15 种球员类型，4值 Lerp 映射）
- OVR 预算系统（总评到 99 时停止加点，只回退当前属性）
- 53 个徽章系统（解锁/锁定状态、tier 要求、token 消耗、自动降级）
- 动画系统（解锁状态、属性要求、点击查看详情）
- Cap Breakers 显示（集成到属性展开区域）
- 属性高亮逻辑（到上限或 OVR=99 时变灰）

## UI 设计

采用 IGotYou 项目风格：
- **全屏沉浸式**：深墨背景 #1C1B1E + 金色主色 #E0AE40
- **渐变遮罩**：顶部和底部渐变遮罩，内容滚动时柔和淡出
- **可展开顶部卡片**：总评 + 位置选择 + 身体数据，点击展开/收起
- **加减按钮控件**：替代滑块，支持长按连续调整
- **居中弹窗**：徽章详情使用居中弹窗，背景模糊

## 数据集

**位置：** `/Volumes/TUF ESD-T1A Media/3J37 Builder/nba2k27-builder-dataset-main/`

**来源：** NBA 2K HQ 官方 app 的 native rules engine 直接调用测量，非估算。

**核心文件：**
- `tuning/progression_attributes.txt` — 16,114 行完整 tuning 数据
- `bodies/legal_bodies.json` — 5 个位置的合法身高/体重/臂展范围
- `bodies/attribute_caps_sample.json` — PG 参考体型的 21 个属性上限（验证样本）
- `reference/attributes.json` — 21 个属性定义
- `badges/` — 53 个徽章定义、tier 要求、token 消耗
- `cap_breakers/gains_by_rating.json` — Cap Breakers 增益数据
- `animations/glossary.json` — 完整动画列表（2914 个动作）

## 项目结构

```
builder_3j37/
├── lib/
│   ├── main.dart                    # 应用入口，主题配置
│   ├── theme/
│   │   └── app_tokens.dart          # 设计令牌（颜色、间距、字体、渐变）
│   ├── data/
│   │   ├── models/
│   │   │   ├── enums.dart           # Position, Discipline, BadgeTier
│   │   │   ├── attribute.dart       # AttributeDef, BodyConfig, LegalBody
│   │   │   ├── badge_data.dart      # BadgeDef, TierRequirement, TokenCost
│   │   │   └── animation_data.dart  # AnimTab, AnimGroup, AnimEntry
│   │   └── services/
│   │       ├── tuning_parser.dart   # 解析 tuning 数据，属性上限计算，OVR 计算
│   │       ├── dataset_loader.dart  # 加载所有 JSON 数据集
│   │       └── builder_state.dart   # 状态管理（Provider），徽章自动降级
│   ├── screens/
│   │   └── builder_screen.dart      # 主界面，全屏沉浸式布局
│   └── widgets/
│       ├── overall_display.dart     # 可展开顶部卡片（总评+位置+身体）
│       ├── position_selector.dart   # 位置选择器（5个按钮）
│       ├── body_configurator.dart   # 身高/体重/臂展加减控件
│       ├── attribute_group.dart     # 21 属性（加减按钮+徽章+Cap Breakers）
│       ├── plus_minus_control.dart  # 通用加减按钮组件
│       ├── badge_panel.dart         # 徽章页面（token 预算+徽章列表）
│       ├── animation_panel.dart     # 动画页面（标签页+分组+解锁状态）
│       ├── cap_breakers_panel.dart  # Cap Breakers 面板
│       └── center_dialog.dart       # 居中弹窗组件（背景模糊）
├── assets/data/                     # JSON 数据文件
├── tool/flutter                     # Flutter 入口
└── tool/analyze                     # 静态检查
```

## 属性系统

### 属性控件
- **加减按钮**：点击 +/- 调整属性值
- **长按加速**：300ms 后开始持续调整，600ms 后加速，1秒后更快
- **显示格式**：`属性名` `[-][+]` `当前值/上限值`
- **颜色逻辑**：
  - 当前值：白色（可加）/ 灰色（已满）
  - 上限值：学科主题色

### Cap Breakers
- 每个属性最多 5 个 Cap Breakers
- 集成在属性展开区域，徽章下方
- 使用 `near_caps` 场景数据（优先），回退到 `isolated`
- 数据来自 `gains_by_rating.json`

### 属性联动约束
- 提高 source → target >= source - MaxDelta
- 降低 source → 传播降低（双向传播）

## 徽章系统

### 徽章显示
- **已装备**：粗边框（3px），学科主题色
- **已解锁**：普通边框，右侧方块显示最高等级颜色
- **未解锁**：半透明，灰色边框

### 徽章详情弹窗
- 居中弹窗，背景模糊
- 显示身高限制和当前身高
- 四个等级（Bronze/Silver/Gold/Hall of Fame）
- 点击等级框直接装备/卸装
- 自动降级：属性降低时自动降级不满足条件的徽章

### Token 系统
- 类别标题显示 Token：`Finishing 15/20`
- 徽章页面顶部显示总 Token
- Token 根据属性 rating 计算

## 计算公式

### OVR 总评
```dart
// 15 种球员类型，取最高分
num = sum(w[a] * s(a, r[a]) * r[a] for a in attrs)
den = sum(w[a] * s(a, r[a])        for a in attrs)
raw = num / den
ovr = outMin + (raw - inMin) / (inMax - inMin) * (outMax - outMin)
```

### 属性上限
```
cap = clamp(round(25 + 74 × HeightMult × WeightMult × WingspanMult), 25, 99)
```
- 使用 NBA-only 数据（不包含 WNBA），21/21 与游戏实际值完全匹配
- 验证数据：`bodies/attribute_caps_sample.json`

## UI 规范

### 颜色
| 角色 | 颜色 | HEX |
|---|---|---|
| 背景 | 深墨 | #1C1B1E |
| 表面 | 暗褐 | #2D2A24 |
| 主色 | 金色 | #E0AE40 |
| 文字 | 暖白 | #F2E9D6 |

### 学科颜色
| 学科 | 颜色 |
|---|---|
| Finishing | 蓝色 #3764B3 |
| Shooting | 绿色 #61AF57 |
| Playmaking | 橙色 #E29754 |
| Defense | 红色 #DE574B |
| Rebounding | 紫色 #9785EA |
| Physicals | 棕色 #A27D32 |

### 字体
- 全局：Noto Serif SC（思源宋体）
- 圆角：2px（直角）

## 运行命令

```bash
cd "/Volumes/TUF ESD-T1A Media/3J37 Builder/builder_3j37"

# 静态检查
./tool/analyze

# 运行到 iPhone
./tool/flutter run -d 00008120-001E38882EF0201E

# 运行到 Web
./tool/flutter run -d chrome

# 清理重建
./tool/flutter clean && ./tool/flutter pub get && ./tool/flutter run
```

## 技术栈

- Flutter 3.47.0 / Dart 3.13.0
- Provider 状态管理
- Google Fonts（思源宋体）
- 全屏沉浸式 + 渐变遮罩布局

---

## ⚠️ 已知问题：Cap Breakers 增益体型依赖

### 问题描述

`gains_by_rating.json` 数据集只包含**一个参考体型**（PG, 6'3/198lbs/6'6臂展）的增益数据。Cap Breaker 增益取决于实际体型（身高、体重、臂展），不同体型有不同的增益值。

**验证数据（用户实际测试 vs App显示）：**

中锋 6'11/253lbs/7'2臂展，所有属性25：

| 属性 | 游戏实际值 | App显示（PG参考） | 差异 |
|------|-----------|-------------------|------|
| Close Shot | 6,5,5,5,5 | 9,8,7,6,6 | ✗ |
| Free Throw | 13,12,10,8,6 | 14,12,10,8,7 | ✗ |
| 3PT | 1,1,1,1,1 | 9,9,7,7,6 | ✗ |
| Speed | 4,4,4,4,3 | 2,2,2,2,2 | ✗ |

### 根因分析

1. **增益计算函数**：`ATTRIBUTES_GetCapBreakerBoostValuesForAttrAtIndex`（游戏引擎内部函数）
   - 输入：属性索引 + 玩家体型 + 所有属性状态
   - 输出：5次 cap breaker 应用的增益值
   - 该函数不在 tuning 文件中，是游戏引擎内部逻辑

2. **tuning 文件不包含增益公式**：
   - `progression_attributes.txt` 包含：属性上限乘数、archetype 权重、OVR 计算参数
   - **不包含**：cap breaker 增益计算公式
   - 增益由游戏引擎根据"winning archetype"动态计算

3. **游戏二进制无法提取公式**：
   - Windows 版 `NBA2K27.exe` 不导出游戏逻辑函数（仅导出 GPU 选择函数）
   - IFF 归档使用 VCZ 压缩（Visual Concepts 专有格式），无法解压
   - 增益数据不是静态表，是运行时计算的

4. **Cap Breaker 上限 = 物理上限（已验证）**：
   - 所有21个属性的 cap breaker 增益在达到物理上限 - 1 时停止
   - 与 `attribute_caps_sample.json` 中的值完全匹配（差值为1，四舍五入原因）

### 可能的解决方案

1. **Native Probe（推荐）**：使用 Android 版 NBA 2K HQ app，通过 `dlopen`/`dlsym` 调用 `ATTRIBUTES_GetCapBreakerBoostValuesForAttrAtIndex`，为多个体型提取完整增益数据。需要 rooted 设备或模拟器。

2. **DLL 注入**：将 DLL 注入 Windows 游戏进程，调用内部函数获取增益。需要游戏运行时执行。

3. **手动测试**：在游戏中创建不同体型的球员，逐个测试所有属性的 cap breaker 增益。

### 当前状态

- 属性上限计算：✓ 完全正确（21/21 匹配）
- OVR 计算：✓ 完全正确
- Cap Breaker 增益：✗ 仅对 PG 参考体型准确，其他体型不准确
