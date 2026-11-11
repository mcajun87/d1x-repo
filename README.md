# d1x 仓库清单与自动同步

Samsung Galaxy Note10 5G（`d1x` / SM-N971N）编译 **Evolution X Android 17（cnb 分支）**
与 **OrangeFox fox_16.0** recovery 所需的全部仓库，以及每日自动同步上游的工作流。

| 文件 | 用途 |
| :-- | :-- |
| [`repos.txt`](repos.txt) | 仓库清单：本地路径 / 我的 fork / 上游 / 分支 / 是否强制同步 |
| [`d1x.xml`](d1x.xml) | `repo` 用的清单，可直接放进 `.repo/local_manifests/` |
| [`.github/workflows/sync-forks.yml`](.github/workflows/sync-forks.yml) | 每天 2 次把 LineageOS 上游同步到我的 fork |

## 为什么要这个仓库

d1x 的 ROM 构建需要 14 个仓库，其中 9 个是 LineageOS 的公共组件
（`hardware/samsung`、`hardware/samsung_slsi-linaro/*` 等）。
它们更新频繁，但又不需要改动，所以做成**纯镜像** + 定时同步；
另外 5 个仓库（设备树、公共树、vendor、内核、以及 OrangeFox 两个树）带本地补丁，
**不能**被上游覆盖，同步脚本只做 fetch 不做覆盖。

## 仓库命名约定：`<上游所有者>_<仓库名>`

所有 fork/镜像一律改名成 `<上游所有者>_<仓库名>`，例如：

| 上游 | 我的仓库 |
| :-- | :-- |
| `Evolution-X/frameworks_av` | `Evolution-X_frameworks_av` |
| `Rocky7842/android_device_samsung_d1x` | `Rocky7842_android_device_samsung_d1x` |
| `oosexgang/hakios-xnu-kernel` | `oosexgang_hakios-xnu-kernel` |
| `iola1999/hackios-xnu-userland` | `iola1999_hackios-xnu-userland` |

**为什么**：AOSP 生态里大量仓库同名（`system_core`、`libcore`、`build`…），
不同上游的同名仓库会互相冲突；加前缀后一眼就能看出它来自谁，
也方便同步脚本由「上游名」直接算出「目标名」，不会改名后忘记更新 workflow。

因此三个同步 workflow 里都**不写死目标仓库名**，而是由上游名拼出来：

| workflow | 目标仓库 |
| :-- | :-- |
| `sync-evolution.yml` | `mcajun87/Evolution-X_<name>` |
| `sync-forks.yml` | `mcajun87/<矩阵里写的 fork>`（LineageOS 系，本来就是 `android_*`） |
| `sync-hackios.yml` | `mcajun87/<上游所有者>_<仓库名>`（直接写在 `hackios-repos.txt` 里） |

## 用法

```sh
repo init -u https://github.com/Evolution-X/manifest -b cnb
cp d1x.xml .repo/local_manifests/
repo sync -c -j8 --force-sync --no-clone-bundle --no-tags
```

## 同步工作流需要一次性配置

本仓库 **Settings → Secrets and variables → Actions** 新增：

| Secret | 值 |
| :-- | :-- |
| `SYNC_TOKEN` | GitHub PAT（classic），勾选 `repo` 权限 |

没有它工作流会直接失败并提示（GitHub 自带的 `GITHUB_TOKEN` 无法写其他仓库）。

## 手动触发

Actions 页面 → `sync forks from upstream` → Run workflow。

## 注意

- 同步只针对 `repos.txt` 里最后一列为 `yes` 的 9 个纯镜像仓库，分支 `lineage-24.0`
- 带补丁的 5 个仓库（设备树/公共树/vendor/内核）**永远不会被自动覆盖**
- 本仓库配套的设备树说明见
  [android_device_samsung_d1x/docs/CUSTOMIZATIONS.md](https://github.com/mcajun87/android_device_samsung_d1x/blob/fox_16.0/docs/CUSTOMIZATIONS.md)

## HackiOS（XNU on Android）仓库

| 仓库 | 说明 |
| :-- | :-- |
| [oosexgang/hakios-xnu-kernel](https://github.com/oosexgang/hakios-xnu-kernel) | 主项目：XNU 内核 + 自带 loader/驱动 + Metal on Adreno，从内存运行，重启回 Android。单仓库，无 submodule；`devices/` `socs/` `drivers/` 分层 |
| [iola1999/hackios-redmi-k90-annibale](https://github.com/iola1999/hackios-redmi-k90-annibale) | 机型移植工作区范例（REDMI K90 / SM8750）：以 submodule 指向自己的 `hakios-xnu-kernel`、`hakios-xnu-userland`、`TrollStore` 的 `<device>-port` 分支 |
| [corellium/projectsandcastle](https://github.com/corellium/projectsandcastle) | 前身项目（Android/Linux on iPhone），固件打包与 loader 可参考 |

清单见 [`hackios-repos.txt`](hackios-repos.txt)，同步见
[`.github/workflows/sync-hackios.yml`](.github/workflows/sync-hackios.yml)
（每天两次，只强制同步清单里写的分支，不会动你自己的移植分支）。

## Evolution X 上游仓库

ROM 构建还需要 Evolution-X 自己的仓库（`snippets/evolution.xml` 里 `remote="evo"` 的全部），
清单见 [`evo-repos.txt`](evo-repos.txt)，同步见
[`.github/workflows/sync-evolution.yml`](.github/workflows/sync-evolution.yml)。

- 清单里**只写上游仓库名**（如 `frameworks_av`），workflow 自动拼出
  `https://github.com/Evolution-X/<name>.git` 和
  `https://github.com/mcajun87/Evolution-X_<name>.git`，所以改名之后不会再出现
  「清单和实际仓库名对不上」的问题
- 每天两次（北京 13:43 / 01:43），也可在 Actions 页手动触发并指定单个上游仓库名
- 这些是**纯镜像**，同步会把所有分支强制对齐上游；要改的东西请放进
  `repos.txt` 里标记 `no` 的仓库（设备树 / 内核 / vendor）
- 同样需要 secret `SYNC_TOKEN`
- 目前镜像了 74 个 Evolution-X 仓库（`cnb` 清单里 `remote="evo"` 的那一批）

## OTA 更新（让别人收到你 ROM 的更新提示）

| 文件 | 作用 |
| :-- | :-- |
| [`ota/d1x.json`](ota/d1x.json) | Evolution X Updater 读取的更新清单 |
| [`.github/workflows/ota-update.yml`](.github/workflows/ota-update.yml) | 本仓库**发布 Release 时自动更新** d1x.json |

Raw 地址（设备树里要指到这个）：

```
https://raw.githubusercontent.com/mcajun87/d1x-repo/main/ota/d1x.json
```

设备树侧配置（`device/samsung/exynos9820-common/device-common.mk`）：

```makefile
PRODUCT_PROPERTY_OVERRIDES += \
    lineage.updater.uri=https://raw.githubusercontent.com/mcajun87/d1x-repo/main/ota/d1x.json
```

刷机仍然走 **OrangeFox**（把 ROM zip 放进手机，OrangeFox 里 Install 即可）。

## 设备侧工具（`tools/`）

刷完 ROM 之后用这三个脚本做验证/收尾，全部是幂等的、只改可逆的东西：

| 脚本 | 作用 |
| :-- | :-- |
| `tools/verify-volte.sh` | 只读检查：运营商识别、IMS 属性、`carrier_volte_available_bool`、注册状态、IMS APN、IMS 进程 |
| `tools/extract-stock-backlight.sh` | 从设备自己的 dtbo 里解出**原厂**背光/亮度表（亮度曲线只用原厂值或实测值，不填占位值） |
| `tools/disable-recovery-restore.sh` | 需要 root：禁用 `org.lineageos.updater`、把 `/vendor` 与 `/system` 下所有"还原官方 recovery"的来源改名成 `.ofdis`、按住 `persist.vendor.recovery_update` |

用法：

```sh
adb push tools/ /data/local/tmp/d1x-tools
adb shell sh /data/local/tmp/d1x-tools/verify-volte.sh
adb shell su -c "sh /data/local/tmp/d1x-tools/disable-recovery-restore.sh"
```
