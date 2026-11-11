#!/usr/bin/env bash
# 目标项 3：以 root 身份彻底断掉「开机后 OrangeFox 被换回官方 recovery」的所有路径
#
# 需要 root（KernelSU / Magisk 均可）。只做「改名/禁用」，全部可逆。
# 用法：su -c ./disable-recovery-restore.sh        或    adb shell su -c "sh /data/local/tmp/disable-recovery-restore.sh"
set -u
say(){ echo "[$(date +%H:%M:%S)] $*"; }

say "当前 uid=$(id -u)"

# ---------- 1. 关掉 LineageOS 的 OTA 更新器 ----------
say "=== 1. 禁用 org.lineageos.updater ==="
pm disable-user --user 0 org.lineageos.updater 2>&1 | head -2
pm list packages -d 2>/dev/null | grep -i updater || say "  （未在禁用列表里）"

# ---------- 2. vendor 侧的官方 recovery 还原机制 ----------
say "=== 2. 处理 /vendor 的还原来源 ==="
V=/dev/block/mapper/vendor
[ -e "$V" ] || V=$(readlink -f /dev/block/by-name/vendor)
M=/data/local/tmp/of_vendor
mkdir -p "$M"
if mount -o rw "$V" "$M" 2>/dev/null; then
    for f in "$M/etc/recovery.img" "$M/bin/install-recovery.sh" \
             "$M/etc/init/vendor_flash_recovery.rc" "$M/recovery-from-boot.p"; do
        if [ -e "$f" ] && [ ! -e "$f.ofdis" ]; then
            mv "$f" "$f.ofdis" && say "  已改名 $f"
        fi
    done
    sync
    umount "$M"
    say "  vendor 处理完成"
else
    say "  ⚠ vendor 挂载失败（可能 verity 强制），跳过"
fi
rmdir "$M" 2>/dev/null

# ---------- 3. /system 侧的 AOSP 机制 ----------
say "=== 3. 处理 /system 的还原来源 ==="
S=/dev/block/mapper/system
[ -e "$S" ] || S=$(readlink -f /dev/block/by-name/system)
M2=/data/local/tmp/of_system
mkdir -p "$M2"
if mount -o rw "$S" "$M2" 2>/dev/null; then
    for f in "$M2/bin/install-recovery.sh" "$M2/etc/install-recovery.sh" \
             "$M2/recovery-from-boot.p" "$M2/etc/init/install-recovery.rc"; do
        if [ -e "$f" ] && [ ! -e "$f.ofdis" ]; then
            mv "$f" "$f.ofdis" && say "  已改名 $f"
        fi
    done
    sync
    umount "$M2"
    say "  system 处理完成"
else
    say "  ⚠ system 挂载失败，跳过"
fi
rmdir "$M2" 2>/dev/null

# ---------- 4. persist 属性 ----------
say "=== 4. persist.vendor.recovery_update ==="
setprop persist.vendor.recovery_update false 2>/dev/null
say "  当前值: [$(getprop persist.vendor.recovery_update)]"

# ---------- 5. 结果 ----------
say "=== 5. 结果核对 ==="
pm list packages -d 2>/dev/null | grep -i updater && say "  ✅ updater 已禁用" || say "  ⚠ updater 未禁用"
getprop init.svc.vendor_flash_recovery | sed 's/^/  vendor_flash_recovery 服务状态: /'
say "完成。重启后确认 OrangeFox 仍在：adb reboot recovery"
