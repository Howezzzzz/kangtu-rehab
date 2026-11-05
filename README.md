<div align="center">

<img src="docs/screenshots/banner-kangtu.png" alt="康途 Kangtu — Rehab &amp; Fitness" width="860" />

<br/>

<img src="assets/img/brand_full.png" width="94" alt="康途 Kangtu" />

# 康途

> **Based on [GymMane](https://github.com/InlitX/GymMane) by InlitX** —— 本项目是它的分支（fork），代码遵循 GPLv3，美术资源遵循 CC BY-SA 4.0，并遵守本仓库的[附加条款](ADDITIONAL_TERMS.md)。

一个**离线的**康复与健身记录应用（Android）。点身体部位选动作、记录组数、看着数字涨。

<p>
  <img alt="Android 7.0+" src="https://img.shields.io/badge/Android-7.0%2B-3DDC84?style=flat&logo=android&logoColor=white" />
  <img alt="License GPLv3" src="https://img.shields.io/badge/Code-GPLv3-C2410C?style=flat&logo=gnu&logoColor=white" />
  <img alt="Art CC BY-SA 4.0" src="https://img.shields.io/badge/Art-CC%20BY--SA%204.0-8A6B41?style=flat&logo=creativecommons&logoColor=white" />
</p>

**下载**：从 [GitHub Releases](https://github.com/Howezzzzz/kangtu-rehab/releases) 获取 —— 本项目自行分发，未上架 F-Droid / IzzyOnDroid / OpenAPK 等商店。不确定下哪个就选 `arm64-v8a`。

</div>

---

## ⚠️ 本仓库当前状态：重做中

这一版是以**上游 GymMane v2.0.0 的纯净代码为基线**重建的。**已完成**：

| 模块 | 状态 |
|---|---|
| 应用内「检查更新」—— 本应用**唯一的联网功能**（清单 SHA-256 校验 + 安装前签名比对） | ✅ 已接入 |
| 品牌与视觉 —— 自有 LOGO 四形态、启动/自适应/通知图标、青绿配色、品牌名按语言（中文「康途」/ 其他「Kangtu」） | ✅ 已接入 |
| 包名独立 —— `com.kangtu.app`（可与上游 GymMane 共存） | ✅ 已接入 |
| 自有 CI / 发布流水线 —— 测试门禁 → 出包 → 发版 → 回写更新清单 | ✅ 已接入 |

**待搬入**（因此当前版本**没有**这些）：康复模块（档案 / 安全门 / AI 提示词往返 / 离线手册）、统一「日志」、自测基线（康复自评）、计划周期与自动进阶、动作库扩展与其中文翻译。

> 也就是说：**下面的功能说明是上游原有的能力（这些都在）**，扩展功能会随后续搬入补齐。

## 功能

**训练**
- 人体图谱（正面 / 背面）：点一下想练的部位
- 次数、重量，带自定义铃声的组间休息计时器；组类型（热身 / 正式 / 递减 / 力竭）与 RPE / RIR
- 超级组、每侧配重片、可按器材自动计算
- 可分组、复制、排期的训练计划；实时通知与重启不丢训练
- 计时循环训练、训练语音报组、备选动作（器械被占时换一个）

**进度**
- 训练量、连续打卡、每周目标与个人纪录（PR）
- 力量曲线（估算 1RM、相对体重力量）、活动热力图与肌群分布
- 进度照片时间线、体重与十项身体测量
- 等级、勋章，以及分享用的贴纸

**动作与工具**
- **466 个动作**（上游内置），带动画与分步说明；可按肌群 / 器材 / 难度筛选，也能**创建自己的动作**
- 任何动作的插图都可换成**你自己的照片、GIF 或视频**
- **场地**：告诉它你有哪些器材，只推荐用得上的
- 日历形式的训练日志，支持照片、视频
- **训练计算器**：1RM、杠铃片、BMI、卡路里、体脂率、FFMI、热身组、RPE 换算、DOTS、Wilks
- **五个桌面小组件**：今天、本周、统计、身体、活动热力图

**你的数据**
- 导出 **CSV**，或包含照片与视频的完整 **ZIP 备份**（也能再导入回来）
- 从 **Hevy**、**Strong**、**Lyfta**、**FitNotes**、**openGym** 或任意 CSV 导入历史
- 把一次训练导出为 `.fit` 上传 **Strava**
- 无账号、无广告、无统计、无追踪；数据只留在手机上
- **17 种语言**，浅色 / 深色 / AMOLED，kg 或 lb
- 一键删除全部数据

**饮食（Beta，默认关闭）**
热量与三大营养素、500+ 种带图食物、自定义食物与菜品、饮水、蛋白粉、补剂、备餐计划。
**没有扫码、没有在线食物库**；不需要就在「设置 › 测试版」里关掉。

## 下载

| 平台 | 状态 |
|---|---|
| Android 7.0+ | 已支持 |
| Wear OS 3+ | 随包内置，尚未真机验证 |
| iOS 15+ | 开发中 |
| 桌面端 | 计划中 |

## 隐私与权限

无账号、无广告、无统计、无追踪。训练记录、照片与笔记都只存在手机上。
康途确实申请了几项权限，逐项说明：

| 权限 | 用途 |
|---|---|
| `INTERNET` / `ACCESS_NETWORK_STATE` | **只在你手动点「设置 → 检查更新」时**联网：读取仓库里的版本清单（含国内镜像）并可选下载更新包。启动时不会自动联网 |
| `REQUEST_INSTALL_PACKAGES` | 下载完更新包后调起系统安装器（是否允许「安装未知应用」由你在系统里决定） |
| `POST_NOTIFICATIONS` / `POST_PROMOTED_NOTIFICATIONS` | 训练提醒、组间休息与实时训练通知 |
| `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` | 精确到点的训练提醒（否则系统会推迟） |
| `USE_FULL_SCREEN_INTENT` / `VIBRATE` / `WAKE_LOCK` / `RECEIVE_BOOT_COMPLETED` | 训练中的全屏提醒、震动、保持屏幕/计时、重启后恢复提醒 |
| `WRITE_EXTERNAL_STORAGE`（仅 Android 9 及以下） | 把分享出去的图片存到相册 |
| `android.permission.health.*`（步数、心率、睡眠、体重等 14 项**读取**） | 只有你主动连接 Health Connect 后，才读取你勾选的数据用于展示（如步数、心率） |
| `android.permission.health.WRITE_EXERCISE`（**写入**） | 只有你开启后，才把完成的训练**写入** Health Connect（不会写入其它任何内容） |

除上述之外不申请任何权限；相机/相册仅在你自己选图时调用系统选择器。

## 开源、署名与许可

- 上游项目：[InlitX/GymMane](https://github.com/InlitX/GymMane)（GPLv3）。本分支保留其署名与许可要求：请见 [LICENSE](LICENSE)、[ADDITIONAL_TERMS.md](ADDITIONAL_TERMS.md)、[CREDITS.md](CREDITS.md)。
- 代码：**GPLv3**；美术资源：**CC BY-SA 4.0**。
- 动作库中一部分条目来自 [RepDB](https://repdb.co) free tier，署名保留在应用内的关于页。

## 参与贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [TRANSLATING.md](TRANSLATING.md)。
