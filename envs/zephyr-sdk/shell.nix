{ pkgs ? import <nixpkgs> { }
, extraPkgs ? [ ]
}:
let
  python-packages = pkgs.python3.withPackages (p: with p; [
    autopep8
    pyelftools
    pyyaml
    pykwalify
    canopen
    packaging
    progress
    psutil
    anytree
    intelhex
    west
    imgtool

    cryptography
    intelhex
    click
    cbor2

    # For mcuboot CI
    toml

    # For twister
    tabulate
    ply

    # For TFM
    pyasn1
    graphviz
    jinja2

    requests
    beautifulsoup4
  ]);

  # Build the Zephyr SDK as a nix package.
  new-zephyr-sdk-pkg =
    { stdenvNoCC
    , fetchurl
    , autoPatchelfHook
    , cmake
    , file
    , glibc_multi
    , libusb
    , python38
    , wget
    , which
    , system ? builtins.currentSystem
    }:
    let
      version = "0.16.4";

      systemFixup = {
        x86_64-linux = "linux-x86_64";
        aarch64-linux = "linux-aarch64";
        x86_64-darwin = "macos-x86_64";
        aarch64-darwin = "macos-aarch64";
      };

      url = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/" +
        "v${version}/zephyr-sdk-${version}_${systemFixup.${system}}.tar.xz";

      hashes = {
        x86_64-linux = "sha256-0BmqqjQlyoQliCm1GOsfhy6XNu1Py7bZQIxMs3zSfjE=";
        aarch64-linux = "sha256-anh8zyeuQjF7xKo55D83waTds0T7AXkcgk/TYa0qd0w=";
        x86_64-darwin = "sha256-u9c2PvbB7LdzL/NFmKvINpmGI3E7lBOtTtZnzEU34E4=";
        aarch64-darwin = "sha256-WRR85c73F5nKZk3uw3k4rb2Pw/xrlJZq7aP0NfEq0Sk=";
      };
    in
    stdenvNoCC.mkDerivation {
      name = "zephyr-sdk";
      inherit version;

      src = fetchurl {
        inherit url;
        hash = hashes.${system};
      };

      srcRoot = ".";

      nativeBuildInputs = [
        autoPatchelfHook

        # Required by setup script
        cmake
        file
        python38
        wget
        which
      ];

      phases = [ "installPhase" "fixupPhase" ];
      installPhase = ''
        mkdir -p $out
        tar -xf $src -C $out --strip-components=1
        (cd $out; bash ./setup.sh -h)
        rm $out/zephyr-sdk-x86_64-hosttools-standalone-0.9.sh
        rm $out/sysroots/*-pokysdk-*/lib/lib{anl,BrokenLocale,c,dl,m,mvec,nsl,nss_compat,nss_dns,nss_files,pthread,resolv,rt,util}.so*
      '';
    };
  zephyr-sdk = pkgs.callPackage new-zephyr-sdk-pkg { };

  packages = with pkgs; [
    # Tools for building the languages we are using
    llvmPackages_16.clang-unwrapped # Includes clang-format options Zephyr uses
    gcc_multi
    glibc_multi

    # Dependencies of the Zephyr build system.
    (python-packages)
    cmake
    ninja
    gperf
    python3
    ccache
    dtc
    gmp.dev

    zephyr-sdk
  ];
in
pkgs.mkShell {
  nativeBuildInputs = [ packages ];

  # For Zephyr work, we need to initialize some environment variables,
  # and then invoke the zephyr setup script.
  shellHook = ''
    export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
    export ZEPHYR_SDK_INSTALL_DIR=${zephyr-sdk}
  '';
}
