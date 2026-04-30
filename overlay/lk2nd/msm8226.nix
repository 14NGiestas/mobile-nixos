# Build lk2nd for MSM8226 (Motorola Titan)
# lk2nd is a secondary bootloader for the ARM device
{ stdenv
, fetchFromGitHub
, gcc-arm-embedded
, dtc
, python3
}:

let
  python = python3.withPackages (p: [ p.libfdt ]);
in

stdenv.mkDerivation {
  pname = "lk2nd";
  version = "22.0-msm8226-titan-clean-v35";

  src = fetchFromGitHub {
    repo = "lk2nd";
    owner = "msm8916-mainline";
    rev = "refs/tags/22.0";
    hash = "sha256-PCpOWwBUkcRn6KTJTJ7UiVcpGt67qP2dLhlcplKNOo0=";
  };

  # Mix of native and cross-compile tools
  nativeBuildInputs = [
    gcc-arm-embedded
    dtc
    python
  ];

  # Make libfdt library available at runtime (dtc includes it)
  LD_LIBRARY_PATH = "${dtc}/lib:$LD_LIBRARY_PATH";

  # Skip standard configure phase
  dontConfigure = true;

  # Patch the dtbTool and mkbootimg scripts to handle individual file arguments
   postPatch = ''
     # Use patchShebangs to fix all Python/shell shebangs in scripts
     patchShebangs lk2nd/scripts/
     
     # Apply enhanced debug patch (multiple checkpoints with vibrations)
     patch -p1 < ${./msm8226-debug-enhanced.patch}
    
    # Patch dtbTool to convert individual file arguments to directory format
    # The source script expects a directory, but the Makefile passes individual .dtb files
    cat >> lk2nd/scripts/dtbTool << 'PATCH_EOF'

# Patch: Convert individual DTB file arguments to directory argument
import tempfile, os
_orig_argv = list(sys.argv)
dtb_files = []
new_argv = []
i = 1
while i < len(sys.argv):
    if sys.argv[i] == "-o":
        new_argv.extend([sys.argv[i], sys.argv[i+1]])
        i += 2
    elif sys.argv[i].endswith(".dtb"):
        # Found first DTB file - collect all remaining DTB files
        dtb_files = [a for a in sys.argv[i:] if a.endswith(".dtb") or not a.startswith("-")]
        break
    else:
        new_argv.append(sys.argv[i])
        i += 1

if dtb_files:
    # Create temp directory and symlink DTBs
    temp_dir = tempfile.mkdtemp()
    for dtb_path in dtb_files:
        if dtb_path.endswith(".dtb") and os.path.exists(dtb_path):
            basename = os.path.basename(dtb_path)
            abs_path = os.path.abspath(dtb_path)
            os.symlink(abs_path, os.path.join(temp_dir, basename))
    new_argv.append(temp_dir)
    sys.argv = [sys.argv[0]] + new_argv
PATCH_EOF
  '';

  # Build the MSM8226 secondary bootloader
  # Key insight from msm8226-motorola-titan.dts (lines 13-17):
  # The titan DTB requires special handling because the bootloader looks for custom board id.
  # Options:
  # 1. LK2ND_ADTBS="" - Remove ADTBS (appended DTBs) and only use QCDT
  # 2. LK2ND_DTBS="msm8226-motorola-titan.dtb" - Only include titan DTB
  # 
  # We use option 1 with the full QCDT image since that's what the normal build does.
  buildPhase = ''
    make lk2nd-msm8226 \
      LD=arm-none-eabi-ld \
      TOOLCHAIN_PREFIX=arm-none-eabi- \
      LK2ND_ADTBS=""
  '';

  # Install the bootloader image
  installPhase = ''
    mkdir -p $out/

    # Copy the lk2nd bootloader image
    if [ -f build-lk2nd-msm8226/lk2nd.img ]; then
      cp build-lk2nd-msm8226/lk2nd.img $out/
    else
      echo "ERROR: lk2nd.img not found!"
      find . -name "lk2nd.img"
      exit 1
    fi

    # Try to copy any DTBs that may have been built
    mkdir -p $out/dtb
    find . -name "*.dtb" -type f -exec cp {} $out/dtb/ \; 2>/dev/null || true
    
    # Copy the boot image if available
    if [ -f build-lk2nd-msm8226/lk2nd.img-dtb ]; then
      cp build-lk2nd-msm8226/lk2nd.img-dtb $out/
    fi
    
    if [ -f build-lk2nd-msm8226/qcdt.img ]; then
      cp build-lk2nd-msm8226/qcdt.img $out/
    fi
  '';
}

