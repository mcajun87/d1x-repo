#!/usr/bin/env bash
# 验证 VoLTE / 短信 / 通话录音是否真的可用（目标项 6）
# 只读，不改任何东西。用法：./verify-volte.sh
set -uo pipefail
ADB="${ADB:-adb}"
"$ADB" get-state >/dev/null || { echo "❌ 设备未授权：请在手机上点『允许 USB 调试』"; exit 1; }
r(){ "$ADB" shell "$1" 2>/dev/null | tr -d '\r'; }

echo "================ 1. 运营商识别 ================"
for k in gsm.sim.operator.numeric gsm.sim.operator.alpha gsm.sim.state ro.carrier ro.boot.carrierid; do
  printf '%-30s = [%s]\n' "$k" "$(r "getprop $k")"
done

echo
echo "================ 2. IMS / VoLTE 属性 ================"
r "getprop | grep -i -E 'ims|volte|vt_avail|wfc'" | head -20

echo
echo "================ 3. CarrierConfig 关键项（应为 true） ================"
r "dumpsys carrier_config" | grep -i -E "carrier_volte_available_bool|carrier_volte_provisioned_bool|play_call_recording_tone_bool|hide_ims_apn_bool" | head -10 \
  || echo "（没抓到，可能该机型没有 carrier_config 服务）"

echo
echo "================ 4. 注册状态（LTE + IMS） ================"
r "dumpsys telephony.registry" | grep -o -E "mVoiceRegState=[0-9]+\([A-Z_]+\)|getRilVoiceRadioTechnology=[0-9]+\([A-Z]+\)|mVopsSupport = [0-9]+|mImsRegistrationState[^,]*" | sort -u

echo
echo "================ 5. IMS 进程是否在跑 ================"
r "ps -A" | grep -i -E "ims|carrier" | head -8

echo
echo "================ 6. IMS APN（46001 联通示例） ================"
r "content query --uri content://telephony/carriers" | grep "numeric=4600" | grep -o -E "name=[^,]*, numeric=[0-9]+, .*type=[a-z,_]+" | head -6

echo
echo "================ 7. 通话录音相关（Dialer 配置是编译期写死的） ================"
r "pm list packages" | grep -i -E "dialer|callrecord" | head -5
echo "提示：Dialer 的 call_recording_enabled 在编译期就是 true；录音文件在 /sdcard/Recordings/Call"

echo
echo "================ 8. 建议的实测 ================"
cat <<'EOF'
  1) 拨一个电话 → 通话界面应能看到「录音」按钮
  2) 通话中观察：logcat -b radio | grep -i ims   应出现 IMS 注册/媒体协商
  3) 发一条含 6 位验证码的短信 → 通知栏应能一键复制验证码
  4) 设置 → 网络与互联网 → SIM → 应能看到 VoLTE 开关且可打开
EOF
