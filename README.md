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
