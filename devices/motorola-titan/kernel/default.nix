{ mobile-nixos
, fetchFromGitHub
, ...
}:

mobile-nixos.kernel-builder {
  version = "3.4.113";
  configfile = ./config.armv7l;

  isQcdt = true;
  isModular = false;

  src = fetchFromGitHub {
    owner = "LineageOS";
    repo = "android_kernel_motorola_msm8226";
    rev = "cm-14.1";
    sha256 = "159yrvnpdff4nyqibx0aidw948ia0m57cnly53h6i7w7llxsclvs";
  };

  patches = [ ./kernel.patch ];
  
  makeFlags = [ "CONFIG_NO_ERROR_ON_MISMATCH=y" ];
    
  postPatch = ''
    # Força o desligamento do fixdep (resolve race condition com make ≥ 4.0)
    sed -i '1i KBUILD_NOCMDDEP := 1' Makefile
    
    # GCC 15 + Binutils 2.44 compat flags
    echo 'KBUILD_CFLAGS   += -std=gnu89 -Wno-error -fno-strict-aliasing -fno-delete-null-pointer-checks -fno-tree-loop-distribute-patterns -fno-ipa-icf' >> Makefile
    echo 'HOSTCFLAGS      += -std=gnu89 -Wno-error' >> Makefile
    echo 'KBUILD_AFLAGS   += -march=armv7-a -Wa,-march=armv7-a -Wa,-mimplicit-it=thumb' >> Makefile
    echo 'KBUILD_LDFLAGS  += -Wno-error=section-mismatch' >> Makefile
  '';

}
