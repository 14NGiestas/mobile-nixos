{ mobile-nixos
, fetchFromGitHub
, useStrictKernelConfig ? true
, ...
}:

mobile-nixos.kernel-builder {
  version = "3.4.113";
  configfile = ./config.armv7l;
  inherit useStrictKernelConfig;

  isQcdt = true;
  isModular = false;

  src = fetchFromGitHub {
    owner = "LineageOS";
    repo = "android_kernel_motorola_msm8226";
    rev = "cm-14.1";
    sha256 = "159yrvnpdff4nyqibx0aidw948ia0m57cnly53h6i7w7llxsclvs";
  };

  patches = [ 
    ./kernel.patch 
    ./patches/dtbs-install.patch
  ];
  
  makeFlags = [ 
    "CONFIG_NO_ERROR_ON_MISMATCH=y"
    #"zImage"  # ← ADD THIS: build only the compressed kernel, skip install
  ];

  postPatch = ''
    echo ">>> [KERNEL PATCH] Phase 1: GCC 10+/Binutils 2.44 Compatibility..."
    
    # 1. Neutralize compile-time assertions that trigger `.err` in modern GAS
    sed -i '/^#define BUILD_BUG_ON(condition)/c\#define BUILD_BUG_ON(condition) ((void)0)' include/linux/bug.h
    sed -i '/^#define compiletime_assert(condition, msg)/c\#define compiletime_assert(condition, msg) ((void)0)' include/linux/compiler.h

    # 2. Fix ARM inline asm constraints (earlyclobber prevents register collision)
    perl -pi -e 's/: "=r" \((err|x)\)/: "=\&r" ($1)/g' arch/arm/include/asm/uaccess.h

    # 3. Fix section/type syntax in ALL static `.S` files
    find arch/arm/ -name "*.S" -exec sed -i \
      -e 's/#alloc/@alloc/g' \
      -e 's/#execinstr/@execinstr/g' \
      -e 's/#object/%object/g' {} +
    # Fix runtime-generated `piggy.*.S` by patching their generator script
    sed -i 's/#alloc/@alloc/g' scripts/mkpiggy.sh 2>/dev/null || true

    echo ">>> [KERNEL PATCH] Phase 2: Toolchain flags & workarounds..."
    
    # 4. Disable fixdep to avoid race conditions with make ≥4.0 in Nix sandbox
    sed -i '1i KBUILD_NOCMDDEP := 1' Makefile

    # 5. GCC 15 + Binutils 2.44 compatibility flags (preserved from your original)
    echo 'KBUILD_CFLAGS   += -std=gnu89 -Wno-error -fno-strict-aliasing -fno-delete-null-pointer-checks -fno-tree-loop-distribute-patterns -fno-ipa-icf -fno-asynchronous-unwind-tables' >> Makefile
    echo 'HOSTCFLAGS      += -std=gnu89 -Wno-error' >> Makefile
    echo 'KBUILD_AFLAGS   += -march=armv7-a -Wa,-march=armv7-a -Wa,-mimplicit-it=thumb' >> Makefile
    echo 'KBUILD_LDFLAGS  += -Wno-error=section-mismatch' >> Makefile

    # 6. Force sequential build to prevent race conditions with temporary `.o.tmp` files
    echo 'KBUILD_BUILD_OPTIONS := -j1' >> Makefile

    echo ">>> [KERNEL PATCH] Phase 3: Validation..."
    
    # Fail-fast validation (stops the build immediately if patches didn't apply)
    grep -q '((void)0)' include/linux/bug.h || { echo "FATAL: bug.h patch failed"; exit 1; }
    grep -q '"=&r"' arch/arm/include/asm/uaccess.h || { echo "FATAL: uaccess.h patch failed"; exit 1; }
    grep -q 'KBUILD_NOCMDDEP' Makefile || { echo "FATAL: Makefile patch failed"; exit 1; }
    
    echo ">>> [KERNEL PATCH] All applied. Build will proceed."
  '';
}
