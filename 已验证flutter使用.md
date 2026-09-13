# IGotYou · 环境与工具链

> 版本：v1.0（2026-08-30）
> 依据：SoWhat 已全量跑通的环境方案，IGotYou 逐项对齐，无残留。
> 原则：SDK 本体放本机，项目只放软链 + 统一入口；Cache 全部钉在工作区可写范围内。

---

## 1. 核心结论（先读这段）

| 项 | SoWhat 实测 | IGotYou（本仓库） |
|---|---|---|
| SDK 本体 | 本机 `/Users/jinfeiqing/fvm/versions/3.47.0`（Flutter 3.47.0 stable / Dart 3.13.0），绝不复制进项目 | 同左，共用本机这一份 |
| 项目内软链 | `.fvm/versions/stable -> /Users/jinfeiqing/fvm/versions/3.47.0` | 同左（`readlink` 验证为软链，非实目录） |
| 版本锁定 | `.fvmrc = {"flutter":"stable"}`，进 git | 同左 |
| 统一入口 | `tool/flutter` + `tool/analyze` 两个可执行脚本，进 git | 同左 |
| 隔离缓存 | `.fvm/pub-cache`（pub 包）、`.fvm/analyze-home`（dart analyze） | 同左 |
| git 忽略 | `.gitignore` 整行 `.fvm/`，本体不进 git | 同左 |

日常分工一句话：**代码编辑、文档、静态检查在 Cursor 内；`./tool/flutter run / build / pub get / clean` 一律去 Terminal 跑。**

---

## 2. Flutter + FVM 三件套

FVM 本身只做版本管理。真正沉淀下来的是三件事：

### 2.1 SDK 本体放本机

- 只保留一份 SDK：`/Users/jinfeiqing/fvm/versions/3.47.0`（约 3.6GB）。
- **绝不复制进项目**：省盘 + 省时 + 换版本只换本机这一处，全项目统一。

### 2.2 项目内软链 + 版本锁定

- 项目 `.fvm/versions/stable` 是**软链**，指向本机 SDK；`readlink` 可验证。
- `.fvmrc = {"flutter":"stable"}` 进 git：团队换机器，按 `.fvmrc` 装同一个版本，行为一致。
- `.gitignore` 整行忽略 `.fvm/`：本体与缓存一律不进 git，只提交 `.fvmrc`。

```bash
readlink .fvm/versions/stable
# -> /Users/jinfeiqing/fvm/versions/3.47.0
```

### 2.3 统一入口 tool/flutter + tool/analyze

不依赖 PATH 里的 `flutter` / `fvm`，人人走同一入口。

#### tool/flutter（全文）

```bash
#!/usr/bin/env bash
# 工作区统一的 flutter 入口。
#
# - SDK 本体放在本机固定路径（通过 .fvm/versions/stable 软链解析，指向本机 SDK）
# - PUB_CACHE 固定在工作区 .fvm/pub-cache，与 SDK 隔离
# - 直接 source SDK 的 shared.sh 并调用 shared::execute（对应 stock bin/flutter 的职责）
#
# 用法：tool/flutter pub get / build / run / ...
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="$(cd "$ROOT/.fvm/versions/stable" && pwd)"

export FLUTTER_ROOT="$SDK"
export PUB_CACHE="${PUB_CACHE:-$ROOT/.fvm/pub-cache}"

# 以下为 Flutter 标准 bootstrap（对应 stock bin/flutter 的职责）
BIN_DIR="$SDK/bin"
SHARED_NAME="$BIN_DIR/internal/shared.sh"
PROG_NAME="flutter"

unset CDPATH
source "$SHARED_NAME"
shared::execute "$@"
```

关键点：

- `FLUTTER_ROOT` 钉到本机 SDK。
- `PUB_CACHE` 钉到 `.fvm/pub-cache`，**pub 包不写 `~/.pub-cache`**（默认是写用户主目录，见第 3 节沙箱问题）。
- 等价于官方 `bin/flutter` 的 bootstrap，不自带版本切换。

#### tool/analyze（全文）

```bash
#!/usr/bin/env bash
# 工作区统一静态检查入口：改动后先跑这个，不用等真机构建才发现编译错。
#
# 与 tool/flutter 的区别：直接调用 SDK 内自带 dart 的 analyze，
# 跳过 flutter 工具链的版本自更新（在受限/沙盒环境下会因写权限报错）。
# 用法：tool/analyze [要分析的路径，默认整个工程]
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="$(cd "$ROOT/.fvm/versions/stable" && pwd)"
DART="$SDK/bin/cache/dart-sdk/bin/dart"

# 分析服务器需要写插件状态目录（~/.dartServer）；受限环境下不可写会直接崩溃，
# 固定改用工作区内可写目录（.dart_tool 里已指向 .fvm/pub-cache 的绝对路径，不受影响）。
export HOME="$ROOT/.fvm/analyze-home"
mkdir -p "$HOME"

exec "$DART" analyze "$@"
```

关键点：

- 直接调 SDK 自带 `dart analyze`，**跳过 flutter 工具链的自更新**（自更新要写 SDK `bin/cache`，沙箱下会失败）。
- `HOME` 指到 `.fvm/analyze-home`，让 `~/.dartServer` 的插件状态落到项目内，沙箱内可写。
- 实测 `.fvm/analyze-home/.dartServer` 会累积 `.unlinked2` 等文件，正常。

---

## 3. 沙箱限制（为什么一定要这样分工）

**编辑器内嵌终端写不了用户主目录，是 macOS 沙箱限制，不是「完全磁盘访问」权限问题，也不是外接盘路径问题。**

诊断证据（编辑器内嵌终端实测）：

| 测试 | 结果 |
|---|---|
| 写本机用户主目录（`~/` 任意位置） | ❌ Operation not permitted |
| 写外接盘项目目录 | ✅ 可以 |
| 写 `/tmp` | ✅ 可以 |
| `ps` 等系统调用 | ❌ |

- 给编辑器勾「完全磁盘访问」、重启、重启电脑均无效——沙箱独立于 TCC。
- Terminal / iTerm 不受限。

由此推导出分工：

| 事项 | 在哪跑 | 原因 |
|---|---|---|
| `./tool/flutter run / build / pub get / clean / pub add` | **Terminal** | 要写 SDK cache / `~/.pub-cache` / `~/.dartServer`，沙箱不可写 |
| `./tool/analyze` | **Cursor 内** | `HOME` 已钉到 `.fvm/analyze-home`，全程写工作区 |
| 代码编辑、文档维护 | Cursor 内 | 正常 |

---

## 4. SPM（Swift Package Manager）—— iOS 侧现状

不是手写 `Package.swift`，是 Flutter 3.47 首次真机构建时自动迁移的：

- 最低 iOS 提到 **15.0**。
- 自动改 `ios/Runner.xcodeproj/project.pbxproj`、`AppFrameworkInfo.plist`、`Podfile`。
- 自动加入 SPM 集成 + UIScene 生命周期迁移。
- 现状是**混合态**：`ios/Podfile` / `Podfile.lock` / `ios/Pods/` 都还在，插件（如 flutter_secure_storage）已是 Swift Package，但工程仍保留 CocoaPods。
- 构建时提示「建议手动迁到纯 SPM」——**待办，发 iOS 版前再切**。
- `.gitignore` 已有 `.swiftpm/` 忽略。

**换 SDK 后的一次性报错**：`A precompiled file has been changed since last built. Please run "flutter clean"`。
处理：`./tool/flutter clean`，并删除 `~/Library/Developer/Xcode/DerivedData/Runner-*`（或整个 DerivedData），再重新构建。清理后不再出现。

---

## 5. 缓存联动（`.dart_tool` ↔ `.fvm/pub-cache` ↔ `.fvm/analyze-home`）

- `.dart_tool/` 内指向 pub-cache 的**绝对路径**，与 `.fvm/pub-cache` 联动。
- 三块都在 `.fvm/` 下，被 `.gitignore` 忽略，不进 git。
- 换机器/换盘后第一次 `./tool/flutter pub get` 会重新生成 `.dart_tool`，指向新绝对路径，无需手动改。

---

## 6. IGotYou 对齐清单（已执行）

1. **删实目录、重建软链**：删除 `IGotYou/.fvm/versions/stable` 实目录（约 4GB），改为
   `ln -s /Users/jinfeiqing/fvm/versions/3.47.0 .fvm/versions/stable`，`readlink` 验证通过。
2. **复制统一入口**：`tool/flutter`、`tool/analyze` 复制到 `IGotYou/tool/` 并 `chmod +x`，进 git。
3. **配置对齐**：`.fvmrc = {"flutter":"stable"}`；`.gitignore` 整行忽略 `.fvm/`、`.dart_tool/`、`.dart_tmp_home/`；`build/` 忽略保留。
4. **缓存目录**：`.fvm/pub-cache` 由 `tool/flutter` 首次运行时自动生成并填充；`.fvm/analyze-home` 由 `tool/analyze` 首次运行时 `mkdir -p` 生成。

**无残留确认**：`.fvm/versions/` 下只有 `stable` 一个软链，无任何实目录 SDK 副本；外接盘根目录无旧 `.fvm/` 残留；`.fvm/pub-cache` 无 `~/.pub-cache` 混合。

---

## 7. 日常命令速查

```bash
# 一律在 Terminal
./tool/flutter pub get
./tool/flutter run --release -d <device-id>
./tool/flutter build ios
./tool/flutter clean

# 静态检查，Cursor 内可直接跑（也可在 Terminal）
./tool/analyze
./tool/analyze lib

# 换 SDK 后出现 precompiled 报错时
./tool/flutter clean
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
```

---

## 8. 历史与弃用说明（勿再使用）

- 早期方案：项目内直接放一份实目录 SDK（`IGotYou/.fvm/versions/stable` 实目录，4GB）——又慢又占盘，且换版本会分叉，**已删除**。
- 外接盘旧 SDK `/Volumes/TUF ESD-T1A Media/.fvm/`（Flutter 3.38.0）已弃用，可删。
- 不要用 PATH 里的裸 `flutter` / `fvm` 命令，统一走 `./tool/flutter` / `./tool/analyze`。

---

## 9. 本机设备ID速查

| 设备 | ID |
|---|---|
| iPhone (USB) | `00008120-001E38882EF0201E` |

### 日常运行命令

```bash
# 运行到iPhone（release模式）
./tool/flutter run --release -d 00008120-001E38882EF0201E

# 运行到iPhone（debug模式）
./tool/flutter run -d 00008120-001E38882EF0201E
```

