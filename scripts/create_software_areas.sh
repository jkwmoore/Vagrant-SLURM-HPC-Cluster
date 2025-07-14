#!/bin/bash

set -euo pipefail

BASE="/opt/software"

# Predefined lists
COMMON_ARCHES=("x86_64" "aarch64" "ppc64le" "s390x")
COMMON_OS=("EL8" "EL9" "Ubuntu20.04" "Ubuntu22.04")

# Prompt helper function to get selections
prompt_selection() {
  local prompt_msg="$1"
  local -n options_ref=$2
  local var_name="$3"

  echo "$prompt_msg"
  echo "Available options: ${options_ref[*]}"
  read -rp "Enter selections separated by commas: " input

  IFS=',' read -ra selected <<< "$input"
  local valid_selections=()

  for sel in "${selected[@]}"; do
    sel_trimmed=$(echo "$sel" | xargs) # trim spaces
    if [[ " ${options_ref[*]} " == *" $sel_trimmed "* ]]; then
      valid_selections+=("$sel_trimmed")
    else
      echo "Warning: '$sel_trimmed' is not valid and will be skipped."
    fi
  done

  if [ ${#valid_selections[@]} -eq 0 ]; then
    echo "No valid selections made. Exiting."
    exit 1
  fi

  # Return selections by setting a variable indirectly
  eval "$var_name=(\"\${valid_selections[@]}\")"
}

# Get architectures
prompt_selection "Select architectures to create directories for:" COMMON_ARCHES ARCHES

# Get OS versions
prompt_selection "Select OS versions to create directories for:" COMMON_OS OS_VERSIONS

echo "Creating folder structure for architectures: ${ARCHES[*]}"
echo "and OS versions: ${OS_VERSIONS[*]}"

mkdir -p "$BASE"

# common
mkdir -p "$BASE/common/live/software" "$BASE/common/live/modules"
mkdir -p "$BASE/common/test/software" "$BASE/common/test/modules"

# common/eb dirs
mkdir -p "$BASE/common/eb/config"
mkdir -p "$BASE/common/eb/easyblocks"
mkdir -p "$BASE/common/eb/easyconfigs"
mkdir -p "$BASE/common/eb/hooks"
mkdir -p "$BASE/common/eb/media/eb-srcs"

# common/eb logs and repository per arch/os_ver/state
for arch in "${ARCHES[@]}"; do
  for os_ver in "${OS_VERSIONS[@]}"; do
    for state in live test; do
      mkdir -p "$BASE/common/eb/logs/$arch/$os_ver/$state"
      mkdir -p "$BASE/common/eb/repository/$arch/$os_ver/$state"
    done
  done
done

# common/lmod
mkdir -p "$BASE/common/lmod"
mkdir -p "$BASE/common/eb/repository/lmod_bootstrap"
mkdir -p "$BASE/common/lmod/software"
mkdir -p "$BASE/common/lmod/modules"

# arch/os_ver state software/modules
for arch in "${ARCHES[@]}"; do
  for os_ver in "${OS_VERSIONS[@]}"; do
    for state in live test; do
      mkdir -p "$BASE/$arch/$os_ver/$state/software"
      mkdir -p "$BASE/$arch/$os_ver/$state/modules"
    done
  done
done

echo "Folder structure created successfully under $BASE"

echo "Creating EasyBuild config files..."

for arch in "${ARCHES[@]}"; do
  for os_ver in "${OS_VERSIONS[@]}"; do
    for state in live test; do
      cfg_file="$BASE/common/eb/config/${arch}_${os_ver}_${state}.cfg"

      cat > "$cfg_file" <<EOF
# EasyBuild config for ${arch} ${os_ver} (${state})
[config]
group-writable-installdir=true
include-easyblocks = $BASE/common/eb/easyblocks
installpath-software = $BASE/$arch/$os_ver/$state/software
installpath-modules = $BASE/$arch/$os_ver/$state/modules
module-naming-scheme = HierarchicalMNS
modules-tool = Lmod
robot-paths=$BASE/common/eb/easyconfigs:%(DEFAULT_ROBOT_PATHS)s
repositorypath = $BASE/common/eb/repository/$arch/$os_ver/$state
sourcepath = $BASE/common/eb/media/eb-srcs
#hooks = $BASE/common/eb/hooks/default.py
EOF
      echo "  Created $cfg_file"
    done
  done
done

cat > "$BASE/common/eb/config/lmod_bootstrap.cfg" <<EOF
# EasyBuild config for lmod bootstrap
[config]
prefix = $BASE/common/lmod
module-naming-scheme = HierarchicalMNS
modules-tool = Lmod
robot-paths=$BASE/common/eb/easyconfigs:%(DEFAULT_ROBOT_PATHS)s
repositorypath = $BASE/common/eb/repository/lmod_bootstrap
sourcepath = $BASE/common/eb/media/eb-srcs
#hooks = $BASE/common/eb/hooks/default.py
EOF


echo "All EasyBuild config files created."