#!/usr/bin/env bash
# 从设备上取「原厂」显示背光表，供亮度曲线精确映射使用。
#
# 原则：只取原厂 dtbo 里的真实值，绝不填占位值。
# 用法：./extract-stock-backlight.sh [输出目录]
set -euo pipefail
OUT="${1:-./backlight-stock}"
mkdir -p "$OUT"
ADB="${ADB:-adb}"

echo "== 0. 检查 adb =="
"$ADB" get-state >/dev/null || { echo "❌ 设备未授权/未连接：请在手机上点『允许 USB 调试』"; exit 1; }

echo "== 1. 直接读运行中面板的背光节点（最权威） =="
"$ADB" shell 'ls -d /sys/class/backlight/* 2>/dev/null' | tr -d '\r' | while read -r d; do
  [ -z "$d" ] && continue
  echo "--- $d ---"
  for f in max_brightness brightness actual_brightness; do
    v=$("$ADB" shell "cat $d/$f 2>/dev/null" | tr -d '\r')
    echo "  $f = ${v:-<无>}"
  done
done | tee "$OUT/sysfs-backlight.txt"

echo "== 2. 拉取当前 dtbo 分区（原厂值来源） =="
"$ADB" shell 'ls -l /dev/block/by-name/dtbo' | tr -d '\r' || true
"$ADB" root >/dev/null 2>&1 || true
if "$ADB" shell 'dd if=/dev/block/by-name/dtbo of=/data/local/tmp/dtbo.img bs=1M 2>/dev/null; ls -l /data/local/tmp/dtbo.img' | tr -d '\r'; then
  "$ADB" pull /data/local/tmp/dtbo.img "$OUT/dtbo.img" && echo "✅ 已保存 $OUT/dtbo.img"
else
  echo "⚠ 无法读 dtbo（需要 root 或 recovery 环境）"
fi

echo "== 3. 若有 dtbo.img，解出 panel 节点的亮度表 =="
if [ -f "$OUT/dtbo.img" ] && command -v dtc >/dev/null; then
  python3 - "$OUT/dtbo.img" "$OUT" <<'PY'
import struct, sys, os
p, out = sys.argv[1], sys.argv[2]
b = open(p,'rb').read()
magic, total, hdr = struct.unpack('>III', b[:12])
print("dtbo magic=0x%08x total=%d header=%d" % (magic, total, hdr))
# 逐个 entry 拆成 .dtb
e = hdr
n = 0
while e + 16 <= len(b):
    size, off, tid, eid = struct.unpack('>IIII', b[e:e+16])
    if size == 0:
        break
    n += 1
    fn = os.path.join(out, "dtbo-%d.dtb" % n)
    open(fn,'wb').write(b[off:off+size])
    e += 16
print("拆出 %d 个 dtb" % n)
PY
  for f in "$OUT"/dtbo-*.dtb; do
    [ -e "$f" ] || continue
    dtc -I dtb -O dts "$f" -o "${f%.dtb}.dts" 2>/dev/null || true
  done
  echo "--- 在解出的 dts 里找亮度相关属性 ---"
  grep -n -i -E "brightness|bl-table|bl_level|lux|gamma|adaptive" "$OUT"/dtbo-*.dts 2>/dev/null \
    | head -40 | tee "$OUT/brightness-tables.txt"
  echo
  echo "✅ 结果在 $OUT/brightness-tables.txt"
  echo "   把这张表贴给我，我按原厂值生成亮度曲线（不做任何猜测/插值以外的加工）"
else
  echo "⚠ 没有 dtc 或没有 dtbo.img，跳过"
fi
