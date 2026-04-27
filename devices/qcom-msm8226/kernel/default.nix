{ mobile-nixos, pkgs, lib, ... }:

let
  kernel = mobile-nixos.kernel-builder {
    version = "6.16.12";
    configfile = ./config.armv7l;
    isModular = true;
    isQcdt = false;

    src = pkgs.fetchFromGitHub {
      owner = "msm8226-mainline";
      repo = "linux";
      rev = "v6.16.12-msm8226";
      hash = "sha256-ME//u1LS7Y172/YWfcK2kpu5jjVv2vIKmK0u8S25E8c=";
    };

    postPatch = ''
      echo ">>> [MAINLINE] Preparing LLVM/Clang build."
      echo 'LLVM=1' >> Makefile
      echo 'LLVM_IAS=1' >> Makefile
    '';
  };
in
kernel.overrideAttrs (old: {
  # Use HOST python3 for code generation (not target ARM python)
  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.buildPackages.python3 ];
  
  # Explicitly tell the kernel Makefile where the host python3 is
  preBuild = ''
    export PATH="${pkgs.buildPackages.python3}/bin:$PATH"
    export PYTHON="${pkgs.buildPackages.python3}/bin/python3"
  '';
})
