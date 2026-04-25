{ pkgs, lib, ... }:
let
  # Helper para baixar blobs do TheMuppets
  muppets = path: sha256: pkgs.fetchurl {
    url = "https://github.com/TheMuppets/proprietary_vendor_motorola/raw/cm-14.1/titan/proprietary${path}";
    sha256 = "sha256-${sha256}=";
  };

  # === Audio Calibration ===
  bluetooth_cal = muppets "/etc/Bluetooth_cal.acdb" "01w17f08kajwx7yj3q8lk88i51xx7knhp6sy1di8wbi0wf2lhy56";
  general_cal   = muppets "/etc/General_cal.acdb" "0wcx74b05nmi1y5h3qsqn5vi5jqk4445wlm43wfkswvz3dwagrm6";
  global_cal    = muppets "/etc/Global_cal.acdb" "0pfb8yyf5i1v6324vnmflnf28cvwcq3faxgxyg49n76zi2baf1hq";
  handset_cal   = muppets "/etc/Handset_cal.acdb" "07sfava0zk51rxczj41zqr07cbpqx12s81xbfgwsk9qpbsai4kk7";
  hdmi_cal      = muppets "/etc/Hdmi_cal.acdb" "08pl0l6i3vqih6zn3n84hkxjwdnsi7782rk51fcvihl7y4a25rkj";
  headset_cal   = muppets "/etc/Headset_cal.acdb" "1xg3chpgk5qwp59rw0h4dpzcfnq5hyzzx7vl2qhpsm9alkafng2w";
  speaker_cal   = muppets "/etc/Speaker_cal.acdb" "0h8ky5v6ca2d45skcfydzy1lbvqp401jwg7l241z5ny8h4zcfqgw";

  # === Touchscreen Firmware ===
  ts_blu        = muppets "/etc/firmware/BLU_synaptics-s2716-00000000-18a02a-titan.tdat" "1x4vgb3ii3xrbn9dr7kcd3778l8baa6rkwgndyiyz1myyxlazwb4";
  ts_synaptics1 = muppets "/etc/firmware/synaptics-s2716-14061501-18a02a-titan.tdat" "0fnjiz2pmn78s5jq1ynr8nhgvcmv128rfaacj71cphykv5mjlm2v";
  ts_synaptics2 = muppets "/etc/firmware/synaptics-s3310b-14101602-1acbd5-titan.tdat" "0qwza1x7kr7vr6im3vsk1znjmy7ax9arq7dkplgahi3y2ij6l877";

in
# Mudamos o nome para "v2" para forçar o Nix a criar uma derivação nova
pkgs.runCommand "motorola-titan-firmware" {
  meta.license = lib.licenses.unfree;
} ''
  # Audio Calibration -> $out/etc/
  install -Dm644 ${bluetooth_cal} "$out/etc/Bluetooth_cal.acdb"
  install -Dm644 ${general_cal} "$out/etc/General_cal.acdb"
  install -Dm644 ${global_cal} "$out/etc/Global_cal.acdb"
  install -Dm644 ${handset_cal} "$out/etc/Handset_cal.acdb"
  install -Dm644 ${hdmi_cal} "$out/etc/Hdmi_cal.acdb"
  install -Dm644 ${headset_cal} "$out/etc/Headset_cal.acdb"
  install -Dm644 ${speaker_cal} "$out/etc/Speaker_cal.acdb"

  # Touchscreen -> $out/etc/firmware/
  install -Dm644 ${ts_blu} "$out/etc/firmware/BLU_synaptics-s2716-00000000-18a02a-titan.tdat"
  install -Dm644 ${ts_synaptics1} "$out/etc/firmware/synaptics-s2716-14061501-18a02a-titan.tdat"
  install -Dm644 ${ts_synaptics2} "$out/etc/firmware/synaptics-s3310b-14101602-1acbd5-titan.tdat"

  # GPU Adreno 305 (opcional, do linux-firmware padrão)
  # O comando abaixo só executa se o arquivo existir no linux-firmware
  if [ -f "${pkgs.linux-firmware}/lib/firmware/qcom/a305_pfp.fw" ]; then
    install -Dm644 "${pkgs.linux-firmware}/lib/firmware/qcom/a305_pfp.fw" "$out/lib/firmware/qcom/a305_pfp.fw"
  fi
  if [ -f "${pkgs.linux-firmware}/lib/firmware/qcom/a305_pm4.fw" ]; then
    install -Dm644 "${pkgs.linux-firmware}/lib/firmware/qcom/a305_pm4.fw" "$out/lib/firmware/qcom/a305_pm4.fw"
  fi
''
