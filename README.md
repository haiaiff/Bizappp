# iOS 交付说明

## ✅ 已构建好的安装包

`业务系统-unsigned.ipa`（146 KB，v1.3，arm64，未签名）——由 GitHub Actions 的 macOS 机器实际编译产出，可直接拿去用你的企业证书重签。

**当前版本为暗黑模式**，视觉预览见 `设计稿-暗色.png` 与真机对照 `对照-修复前后.png`。

- 包名 `com.bizapp.web`，最低 iOS 15.0，iPhone only
- 未签名（无 `_CodeSignature`），签名工具不会再报"已签名"冲突
- 构建记录：https://github.com/haiaiff/Bizappp/actions



## 暗黑模式（v1.2）

### 设计规格

```
1. 基调：石墨而非纯黑。纯黑在 OLED 上与阴影无法区分，界面会"塌"；#0F1216 带一点冷蓝，
        既压得住长时间盯屏，又能让 1px 描边和层次浮现出来。
2. 图层：#0F1216 页面 → #12161C 弹层 → #171C23 卡片，靠明度而不是投影分层（投影在暗色里几乎不可见）。
3. 信号：只保留一支冷蓝 #5B9BF5，用于进度线、眉标、链接、聚焦描边。其余全部中性。
4. 主按钮：反相——近白 #E9EBEE 填充 + #0F1216 字。暗色界面里"提亮"比"上色"更像主操作，
        而且全屏只有一个这样的块，不喧哗。
5. 字：中文 PingFang SC，拉丁标签 Avenir Next 10.5pt + 1.9 字距，地址 Menlo（等宽，IP 与端口不粘连）。
6. 对比度：正文 15.6:1、次级 8.2:1、三级提示 4.6:1、强调色 6.4:1，全部达 WCAG AA。
```

### 具体改动

| 位置 | 改动 |
| --- | --- |
| 主题令牌 | 全部改为动态色（`UIColor(dynamicProvider:)`），深浅两套值同源，视图层零硬编码色值 |
| 导航栏 | 石墨底 + 近白字 + 无分割线；状态栏自动转白色 |
| 启动屏 | 底色 `#0F1216`，与首屏无缝衔接，不再有亮色闪屏 |
| 断连页 | 同上排版，改为石墨底、近白标题、蓝色眉标、深色描边地址框 |
| 设置页 | 弹层底色抬一级（`#12161C`），输入框聚焦时蓝色 1.5px 描边，键盘自动切深色 |
| 网页内容 | 新增「网页深色」开关（默认开）：对白底老系统注入反色 + 色相回正样式，见下 |
| 外观 | 「⋯」→ 外观：深色 / 浅色 / 跟随系统，默认深色；切换后页面会重新加载 |

### v1.3 修正：网页与外壳的接缝

第一版真机截图暴露出两个问题，都不是配色表能解决的：

1. **纯黑块**：`invert(1)` 把页面白底反成 `#000`，而外壳是石墨色，中间浮出一块边缘锐利的黑板子。
   改成 `invert(.94)`——`out = c + 0.94 × (255 − 2c)`，纯白正好落到 `#0F0F0F`，纯黑落到 `#F0F0F0`，
   灰度关系基本不变，但页面的"白"从此和外壳是同一个色。
2. **冷暖错位**：`invert(1)` 出来的 `#0F1216` 带蓝调，再经 `hue-rotate(180deg)` 被翻成暖调 `#14110D`，
   于是导航栏偏冷、页面偏暖，整屏像拼的。既然网页反色后必然是中性灰，就把暗色令牌全部改成中性：

   | | v1.2 | v1.3 |
   | --- | --- | --- |
   | 页面底 | `#0F1216`（蓝调） | `#0F0F0F`（中性） |
   | 卡片 | `#171C23` | `#1B1B1B` |
   | 分割线 | `#252B34` | `#2B2B2B` |

   信号蓝 `#5B9BF5` 保留——它和页面里的蓝色按钮同属冷色，不打架。
3. **导航与网页之间加 1px 发丝线**（`#2B2B2B`）：两处同色后需要一条界线交代"这是外壳"。

> 判断依据不是猜的：从截图里取样，导航栏实测 `#0F1216`、页面实测 `#14110D`、内容块实测 `#000`。

### 关于「网页深色」

内网 ASP.NET 系统本身没有 dark 样式，WKWebView 也不会替它反色。做法是注入一段 CSS：
`filter: invert(1) hue-rotate(180deg)` 把整页压成深色，再对**大尺寸图片**（≥64px，多为 logo / 照片）
二次反色还原本来颜色，小图标只反一次自然变成浅色。

**这是近似方案，不是原生暗色主题**：如果页面里有大量彩色区块或半透明遮罩，可能出现色偏；
个别老页面的 `position: fixed` 元素也可能位置偏移。遇到就「⋯」→ 关掉「网页深色」，只保留原生外壳的深色。

## 设计说明（v1.1 浅色版，现作为「浅色」外观保留）

### 设计规格

```
1. 用途：员工每天数次进入内网系统的入口。目标不是吸引注意，而是快速进入、状态清楚、不抢戏。
2. 美学方向：Industrial / precision（工业精密感）——纸墨底色、单一强调色、左对齐、细分割线。
3. 色板：#101318 墨（主文字） / #5A6270 次级 / #9AA1AC 三级 / #F3F3F1 纸（背景）
        #FFFFFF 面 / #E2E2DD 分割线 / #1257C7 强调（仅用于进度、标签、链接）
4. 字体：中文 PingFang SC（标题 Semibold 26/24，正文 14–15）；
        拉丁小标签 Avenir Next DemiBold 10.5 + 1.9pt 字距（NO CONNECTION / SERVER ADDRESS）；
        地址 Menlo 12（等宽，避免 IP 与端口挤在一起看不清）
5. 版式：全左对齐、非居中；内容顶部留白 64pt；2pt 进度线贴顶；卡片 4pt 圆角、1px 硬边、不用投影
```

### 具体改了什么

| 位置 | 改动 |
| --- | --- |
| 导航栏 | 从深蓝实心条改为纸色底 + 墨色字 + 无分割线；右侧「⋯」改为原生 `UIMenu`（刷新 / 回到登录页 / Safari 打开 / 更换地址） |
| 加载进度 | 系统横条换成贴顶 2pt 细线，宽度随加载比例增长，加载完成即消失 |
| 启动 | 纯纸色启动屏 + 「业务系统 / CONNECTING」品牌过渡，加载完成后 0.4s 淡出 |
| 断连页 | 从"居中的感叹号 + 两个方按钮"改成左侧编辑部式排版：眉标 → 26pt 标题 → 说明 → 等宽地址框 → 墨色主按钮 → 文字次要按钮 → 底部提示 |
| 设置页 | 系统 Alert 换成卡片式弹层（pageSheet）：眉标、标题、带聚焦描边的输入框、示例、主按钮、脚注；支持键盘避让、空值抖动提示、触感反馈 |
| 交互细节 | 按钮按压有 0.975 缩放 + 6% 透明度变化；主按钮点击有轻触感（`UIImpactFeedbackGenerator`）；错误页淡入 0.28s |
| 启动屏底色 | 从深蓝改为纸色，和首屏与断连页连贯，不再有"蓝屏闪一下" |

> 平台说明：中文字形用系统 PingFang SC。iOS 不允许随便替换中文字体（内置字库 20MB+ 且涉及授权），因此"高级感"落在字重、字距、留白与版式节奏上，而不是换字体。

## 0. 先说清楚：为什么我这边出不了 ipa

ipa 里的可执行文件是 **arm64 Mach-O**，只能用 Apple 的 macOS 工具链（Xcode / iPhoneOS SDK）产出。
签名可以自己来，但**编译这一步绕不过 macOS**——Linux 版 Swift 编译器不带 Darwin 标准库，也没有 iOS SDK，装 Darling 也跑不了 Xcode 工具链。

所以下面给你三条能真正拿到包的路，按你手头的设备选。

| 你的条件 | 走哪条 | 拿到 ipa 耗时 |
| --- | --- | --- |
| 有任意一台 Mac（自己的/同事的/网吧的） | 路线 1 | 约 2 分钟 |
| 有 Windows / 有电脑 | 路线 2（GitHub 免费 macOS 机器代打） | 约 5 分钟 |
| 只有一台 iPhone | 先走路线 3（描述文件，马上能用）；要真 ipa 见第 3.5 节 | — |

---

## 1. 路线 1：有 Mac，一条命令出包

把整个目录拷到 Mac 上（或解压 `业务系统-iOS-Xcode工程.zip`），在终端执行：

```bash
cd iOS            # 进到含 BizApp.xcodeproj 的那一层
./build-ipa.sh
```

脚本做的事：`xcodebuild` 编译 Release + arm64，全部签名项关掉（`CODE_SIGNING_ALLOWED=NO`），然后把 `.app` 装进 `Payload/` 打成 `BizApp-unsigned.ipa`。

产出：同目录下 `BizApp-unsigned.ipa`，直接丢给你的签名工具即可。

> 脚本里没写 `-destination`，如果报 scheme 相关错误，先执行一次
> `xcodebuild -list -project BizApp.xcodeproj` 确认 scheme 名为 `BizApp`。
> 也可以用 Xcode 图形界面：打开工程 → Product → Scheme → Edit Scheme → Run → Build Configuration 选 Release，然后 Product → Archive，导出时选 "None" 不签名。

## 2. 路线 2：没有 Mac，让 GitHub 的 macOS 机器帮你打

仓库里已经放好 `.github/workflows/build-ipa.yml`，推上去就自动出包。

**一次性准备（3 条命令）：**

```bash
cd iOS
git init -b main
git add .
git commit -m "init"
# 先在 GitHub 网页上建一个空仓库（私有即可），然后：
git remote add origin https://github.com/你的用户名/仓库名.git
git push -u origin main
```

> 注意：要把 **iOS 目录里的内容**推到仓库根目录（仓库根下要能看到 `BizApp.xcodeproj`、`build-ipa.sh`、`.github/`），不是把 iOS 文件夹本身塞进去。

**之后：**

1. 打开仓库 → 顶部 **Actions** → 左侧「Build unsigned IPA」→ 会自动跑起来（首次可能要点一下 "I understand my workflows, go ahead"）
2. 等 2~4 分钟，绿色对勾后点进这次运行
3. 页面底部 **Artifacts** → 下载 `BizApp-unsigned-ipa.zip`，解压得到 `BizApp-unsigned.ipa`
4. 拿这个 ipa 去签名

免费账号额度：私有仓库每月 2000 分钟，macOS 按 10 倍计费（≈200 分钟真实时长），一次构建约 3 分钟，够用几十次。

## 3. 路线 3：不装 App，用描述文件上主屏

文件：`业务系统-WebClip.mobileconfig`

1. 传到 iPhone（AirDrop / 微信文件传输助手 / 邮件）
2. 用 **Safari** 打开（微信里要先「…」→ 用其他应用打开 → Safari）
3. 设置 → 通用 → VPN 与设备管理 → 已下载的描述文件 → 安装 → 输锁屏密码
4. 桌面出现「业务系统」图标，点开是全屏登录页，无地址栏

图标（512×512）已内嵌在描述文件里。地址是写死的，换 IP 要重装一份。

同目录另有一个 `业务系统-WebClip-窗口模式.mobileconfig`，区别是带 Safari 工具栏（可刷新、回退），页面卡住时更好恢复；两个只能装一个。

## 3.5 只有一台 iPhone，却非要真 App

手机端无法替代编译环节（也没有能在手机上跑 Xcode 的工具），所以只有三种办法：

**① 先测功能，别急着打包**
描述文件方案装出来的就是全屏网页应用，功能和真 App 差异只在「原生上传/下载处理」和「无 Safari 痕迹」。先用它确认页面在手机上是否可用，能省掉一大圈。

**② 找一个有电脑的人帮你跑一次**（同事、朋友、公司 IT 都行）
需要的就是：一台 Mac（或用 Windows 跑 GitHub 那条）+ 你的企业证书。把 `BizApp-iOS.zip` 发过去，附这段话：

> 麻烦帮我打个 iOS 包，很简单的三步：
> 1. 解压后终端进目录执行 `./build-ipa.sh`（没有 Mac 就走 README 路线 2，GitHub Actions 自动出包）
> 2. 得到 `BizApp-unsigned.ipa`
> 3. 用咱们的企业证书（p12 + mobileprovision）重签一下，把 ipa 或安装链接给我
>
> 这是个 WebView 壳工程，不用改代码。

**③ 找代打包服务**（淘宝/签名平台，几十块钱，手机上就能下单）
把工程压缩包发过去，对方出签好的 ipa 或 itms-services 安装链接。
⚠️ 只发工程文件，**不要**把内网系统的账号密码给任何人；服务商签完的 App 他们理论上能看到包内配置（里面只有服务器地址，没有密码）。

---

## 4. 拿到 ipa 之后怎么签（你自己来）

| 工具 | 说明 |
| --- | --- |
| Sideloadly | Windows/Mac 都有，用 Apple ID 免费签，7 天有效，需要电脑 |
| AltStore / SideStore | 手机上续签，同样 7 天 |
| 爱思助手 | 国内常用，支持自签 ipa |
| 企业证书 / 开发者证书 | 用 `codesign` + `embedded.mobileprovision` 重签，1 年 |
| TrollStore | 越狱/支持机型可直接装**未签名** ipa，不需要签 |

重签命令参考（有 .p12 和 .mobileprovision 时）：

```bash
unzip -o BizApp-unsigned.ipa -d tmp
cp tmp/Payload/BizApp.app/embedded.mobileprovision tmp/ 2>/dev/null
codesign -f -s "iPhone Distribution: 你的公司" --entitlements ent.plist tmp/Payload/BizApp.app
zip -qry BizApp-signed.ipa -C tmp Payload
```

## 5. 工程已实现的能力

| 场景 | 说明 |
| --- | --- |
| 登录态 | 持久化 Cookie（`WKWebsiteDataStore.default()`），杀进程重进不用重新登录 |
| 附件上传 | iOS 上 `<input type=file>` 由 WebKit 原生处理（照片 / 拍照 / 文件），无需额外代码 |
| 文件下载 | `WKDownload`，下完弹分享面板，可存「文件」或转发 |
| 返回 | 左缘右滑返回 + 导航栏返回箭头 |
| `target=_blank` | 强制当前页打开，不会点了没反应 |
| 外站链接 / `tel:` / `mailto:` | 交给 Safari 或拨号盘 |
| 断网 | 「无法连接服务器 + 重试 / 改地址」页面，不是白屏 |
| 下拉刷新 | 已开启 |
| 改服务器地址 | 导航栏右上「⋯」→ 修改服务器地址（改完记住） |
| http 明文 | Info.plist 已开 `NSAllowsArbitraryLoads`，不被 ATS 拦 |

## 6. 二次修改

| 改什么 | 改哪里 |
| --- | --- |
| 默认地址 | `BizApp/WebViewController.swift` 第 10 行 `defaultServer` |
| App 名称 | `BizApp/Info.plist` → `CFBundleDisplayName` |
| 包名 | 工程 target → General → Bundle Identifier（或 `project.pbxproj` 内 `com.bizapp.web`） |
| 图标 | 替换 `BizApp/Assets.xcassets/AppIcon.appiconset/` 内 PNG（1024 那张需不透明、直角） |
| 启动色 | `Assets.xcassets/LaunchBackground.colorset` |

## 7. 已知限制

1. **WKWebView 不能忽略自签 HTTPS 证书**（与 Android WebView 不同）。你现在是 `http://`，无影响；将来若换 https + 自签证书会白屏。
2. 套壳 App 上不了 App Store（4.2 条款），内部用没问题。
3. 已在 GitHub Actions 的 macOS 14 + Xcode 上真实编译通过（产物见文首），不是纸面工程。
