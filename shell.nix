let
  nixpkgs = <nixpkgs>;
in
{ pkgs ? import nixpkgs {} }:

pkgs.mkShell {
  packages = with pkgs; [
    qmk
    curl
    jq
    unzip
  ];
  shellHook =
  # bash
  ''
    qmk_dir=$(git rev-parse --show-toplevel)
    qmk_config_loc="''${XDG_CONFIG_HOME:-$HOME/.config}/qmk/qmk.ini"
    export QMK_HOME="$qmk_dir/zsa_firmware"
    export QMK_USERSPACE="$qmk_dir"

    echo -en "\e[0;34m\
    Setting QMK_HOME='$QMK_HOME' and QMK_USERSPACE='$QMK_USERSPACE'.
    \e[m"

    if [ -f "$qmk_config_loc" ]; then
      echo -e "\e[1;34m\
    Detected QMK config file at $qmk_config_loc!
    If it sets user.qmk_home or user.overlay_dir, these will respectively
    supersede the above set environment variables whenever you run qmk!
    You can check what values are used by running \`qmk env\`.
    \e[m"
    fi
  '';
}
