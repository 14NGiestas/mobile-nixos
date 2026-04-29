{
  stdenv
, fetchFromGitHub
, fetchpatch
, dtc
, gcc-arm-embedded
, python3
}:
let
  python = (python3.withPackages (p: [
    p.libfdt
  ]));

in stdenv.mkDerivation {
  pname = "lk2nd";
  version = "0.3.1-msm8226-titan";

  src = fetchFromGitHub {
    repo = "lk2nd";
    owner = "msm8916-mainline"; # lk2nd principal é aqui agora
    rev = "refs/tags/v0.16.0"; # Versão mais estável para MSM8226
    hash = "sha256-R4v6nK6vT/Q+8Y+qGkO+1D6m7S9K7H3N5V5k6nK6vT/Q="; # Provavelmente errado, mas Nix dirá o certo
  };

  nativeBuildInputs = [
    gcc-arm-embedded
    dtc
    python
  ];

  # Removendo patches antigos do msm8953 que causavam erro
  patches = [];

  postPatch = ''
    patchShebangs --build scripts/
    # Corrigindo dmb() que está faltando na plataforma msm8226 no branch antigo
    # mas em v0.16.0+ deve estar corrigido ou em outro lugar.
  '';

  installPhase = ''
    mkdir -p $out/
    cp ./build-msm8226-secondary/lk2nd.img $out/ || cp ./build-msm8226/lk2nd.img $out/
  '';

  makeFlags = [
    "msm8226-secondary"
    "LD=arm-none-eabi-ld"
    "TOOLCHAIN_PREFIX=arm-none-eabi-"
  ];
}
