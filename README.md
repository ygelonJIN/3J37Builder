# 3J37 Builder — NBA 2K27 MyPLAYER 建模平台

> 基于 NBA 2K27 的跨平台 MyPLAYER 建模工具。使用 Flutter 开发，支持 iOS、Android 和 Web。

![Flutter](https://img.shields.io/badge/Flutter-3.47.0-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.13.0-0175C2?logo=dart)
![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20Web-brightgreen)

---

## 核心功能

### 球员建模系统
- **位置选择**：PG / SG / SF / PF / C 五大位置
- **身体参数**：身高、体重、臂展精确配置，支持 +/- 按钮长按连续调整
- **21 属性系统**：6 大学科 21 个属性，每个有精确物理上限（来自 tuning 数据）
- **属性联动约束**：提高/降低一个属性会联动相关属性（精确移植网站逻辑）

### Cap Breakers 系统（能力突破器）
- **AI 模型计算**：基于机器学习模型的增益计算，21/21 属性与游戏数据完全匹配
- **每属性最多 5 个**：集成在属性展开区域，支持一键应用/撤销
- **状态持久化**：Cap Breaker 应用状态随构建保存

### 徽章系统
- **53 个徽章**：完整徽章定义、tier 要求、token 消耗
- **Token/Slot 预算**：6 大学科独立 Token 和 Slot 预算
- **自动降级**：属性降低时自动降级不满足条件的徽章
- **身高限制**：徽章详情显示身高限制和当前身高状态

### Goal 系统（目标规划）
- **徽章目标**：设定目标徽章等级，自动计算属性需求
- **动画目标**：选择目标动画，追踪解锁进度
- **属性目标**：手动设定属性目标值
- **约束传播**：目标需求自动约束属性下限

### My Builds（我的构建）
- **本地存储**：使用 SharedPreferences 持久化保存
- **导入/导出**：支持 JSON 格式导入导出构建数据
- **分享卡片**：生成 1080x1920 竖版游戏风格分享图片
- **构建管理**：重命名、删除、编辑已有构建

### 国际化支持
- **中英双语**：完整中文/英文界面切换
- **自动记忆**：语言选择持久化到本地存储

---

## 快速开始

### 环境要求

- Flutter SDK 3.47.0+
- Dart SDK 3.13.0+
- iOS 12.0+ / Android API 21+ / Chrome 90+

### 安装运行

```bash
# 克隆项目
git clone <repository-url>
cd "3J37 Builder/builder_3j37"

# 获取依赖
flutter pub get

# 静态检查
./tool/analyze

# 运行到 iPhone
./tool/flutter run -d <device-id>

# 运行到 Web
./tool/flutter run -d chrome

# 清理重建
./tool/flutter clean && ./tool/flutter pub get && ./tool/flutter run
```

---

## 项目结构

```
builder_3j37/lib/
├── main.dart                        # 应用入口，主题配置，Provider 注入
│
├── data/
│   ├── models/
│   │   ├── enums.dart               # Position, Discipline, BadgeTier 枚举
│   │   ├── attribute.dart           # AttributeDef, BodyConfig, LegalBody
│   │   ├── badge_data.dart          # BadgeDef, TierRequirement, TokenCost
│   │   ├── animation_data.dart      # AnimTab, AnimGroup, AnimEntry
│   │   ├── cap_breaker.dart         # CapBreakerState, CapBreakerApplication
│   │   ├── build_save.dart          # BuildSave 构建保存模型
│   │   ├── goal_data.dart           # GoalData, GoalBadge, GoalMove, GoalAttribute
│   │   └── takeover_data.dart       # TakeoverAbility, TakeoverRequirement
│   │
│   └── services/
│       ├── builder_state_v3.dart    # 状态管理（当前版本）
│       ├── dataset_loader.dart      # 数据集加载器
│       ├── tuning_parser.dart       # 解析 tuning 数据，属性上限计算，OVR 计算
│       ├── cap_breaker_engine.dart  # Cap Breaker AI 模型计算引擎
│       ├── constraint_graph_logic.dart # 属性联动约束逻辑
│       ├── website_logic.dart       # 网站核心逻辑移植
│       └── build_storage_service.dart # 构建存储服务
│
├── screens/
│   └── builder_screen.dart          # 主界面，全屏沉浸式布局
│
├── widgets/
│   ├── overall_display.dart         # 可展开顶部卡片（总评+位置+身体）
│   ├── position_selector.dart       # 位置选择器
│   ├── body_configurator.dart       # 身高/体重/臂展加减控件
│   ├── attribute_group.dart         # 21 属性（加减按钮+徽章+Cap Breakers）
│   ├── badge_panel.dart             # 徽章页面
│   ├── animation_panel.dart         # 动画页面
│   ├── cap_breakers_panel_v3.dart   # Cap Breakers 面板
│   ├── goal_card.dart               # Goal 目标卡片
│   ├── takeover_panel.dart          # Takeover 能力面板
│   ├── myb_page.dart                # My Builds 页面
│   ├── share_build_card.dart        # 分享卡片生成
│   ├── center_dialog.dart           # 居中弹窗组件
│   └── language_switch_button.dart  # 语言切换按钮
│
├── theme/
│   └── app_tokens.dart              # 设计令牌（颜色、间距、字体）
│
├── services/
│   ├── locale_service.dart          # 国际化服务
│   └── translations.dart            # 翻译文本
│
└── extensions/
    └── context_extensions.dart      # Context 扩展方法
```

---

## 数据来源

**来源：** NBA 2K HQ 官方 app 的 native rules engine 直接调用测量，非估算。

数据集位于 `builder_3j37/assets/data/` 目录。

---

## 技术栈

- **Flutter** 3.47.0 / **Dart** 3.13.0
- **Provider** 状态管理
- **Google Fonts**（思源宋体）
- **SharedPreferences** 本地存储

---

