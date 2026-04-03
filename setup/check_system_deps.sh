#!/usr/bin/env bash
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later
#
# check_system_deps.sh -- Check system-level dependencies required by R packages
#
# Usage:
#   bash setup/check_system_deps.sh
#
# Checks for: GDAL, GEOS, PROJ, libsndfile, libxml2, GLPK, Rtools/Xcode
# Prints install commands for the detected OS.
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colour helpers ───────────────────────────────────────────────────────────

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  GREEN='\033[32m'
  RED='\033[31m'
  YELLOW='\033[33m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN='' RED='' YELLOW='' BOLD='' RESET=''
fi

ok()   { printf "  %-22s ${GREEN}FOUND${RESET}  %s\n" "$1" "$2"; }
miss() { printf "  %-22s ${RED}MISSING${RESET}\n" "$1"; }
warn() { printf "  %-22s ${YELLOW}UNKNOWN${RESET} %s\n" "$1" "$2"; }

# ── Detect OS ────────────────────────────────────────────────────────────────

detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt-get &>/dev/null; then
      echo "debian"
    elif command -v dnf &>/dev/null; then
      echo "fedora"
    elif command -v pacman &>/dev/null; then
      echo "arch"
    else
      echo "linux"
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    echo "windows"
  else
    echo "unknown"
  fi
}

OS=$(detect_os)

printf "\n${BOLD}=== ecological-agent-skills: System Dependency Check ===${RESET}\n\n"
printf "Detected OS: ${BOLD}%s${RESET}\n\n" "$OS"

MISSING_COUNT=0
FOUND_COUNT=0

# ── Check functions ──────────────────────────────────────────────────────────

check_command() {
  local name="$1"
  local cmd="$2"
  local extra="${3:-}"

  if command -v "$cmd" &>/dev/null; then
    local ver
    ver=$($cmd --version 2>&1 | head -1 || echo "")
    ok "$name" "$ver"
    FOUND_COUNT=$((FOUND_COUNT + 1))
  else
    miss "$name"
    MISSING_COUNT=$((MISSING_COUNT + 1))
  fi
}

check_lib() {
  local name="$1"
  local header="$2"  # header file to look for
  local pkg_config_name="${3:-}"

  # Try pkg-config first
  if [[ -n "$pkg_config_name" ]] && command -v pkg-config &>/dev/null; then
    if pkg-config --exists "$pkg_config_name" 2>/dev/null; then
      local ver
      ver=$(pkg-config --modversion "$pkg_config_name" 2>/dev/null || echo "")
      ok "$name" "v$ver (pkg-config)"
      FOUND_COUNT=$((FOUND_COUNT + 1))
      return
    fi
  fi

  # Try to find the header
  if [[ "$OS" == "windows" ]]; then
    # On Windows, most R packages use pre-compiled binaries; skip header check
    warn "$name" "(Windows: usually included in CRAN binary)"
    return
  fi

  local found=0
  for dir in /usr/include /usr/local/include /opt/homebrew/include; do
    if [[ -f "$dir/$header" ]]; then
      ok "$name" "($dir/$header)"
      FOUND_COUNT=$((FOUND_COUNT + 1))
      found=1
      break
    fi
  done

  if [[ $found -eq 0 ]]; then
    miss "$name"
    MISSING_COUNT=$((MISSING_COUNT + 1))
  fi
}

# ── Required dependencies ────────────────────────────────────────────────────

printf "${BOLD}Core geospatial libraries (required by sf, terra):${RESET}\n"
check_command "GDAL (gdal-config)" "gdal-config"
check_command "GEOS (geos-config)" "geos-config"
check_command "PROJ (proj)"        "proj"

printf "\n${BOLD}Audio libraries (required by soundecology, tuneR):${RESET}\n"
check_lib "libsndfile" "sndfile.h" "sndfile"

printf "\n${BOLD}Other libraries:${RESET}\n"
check_lib "libxml2" "libxml2/libxml/parser.h" "libxml-2.0"
check_lib "GLPK" "glpk.h" "glpk"

printf "\n${BOLD}Build tools:${RESET}\n"
check_command "R" "R"
check_command "Python" "python3"

if [[ "$OS" == "windows" ]]; then
  # Check for Rtools
  if [[ -d "/c/rtools44" ]] || [[ -d "/c/rtools43" ]] || [[ -d "/c/rtools42" ]] || command -v gcc &>/dev/null; then
    ok "Rtools (gcc)" "$(gcc --version 2>&1 | head -1 || echo 'found')"
    FOUND_COUNT=$((FOUND_COUNT + 1))
  else
    miss "Rtools"
    MISSING_COUNT=$((MISSING_COUNT + 1))
  fi
elif [[ "$OS" == "macos" ]]; then
  if xcode-select -p &>/dev/null; then
    ok "Xcode CLI tools" "$(xcode-select -p)"
    FOUND_COUNT=$((FOUND_COUNT + 1))
  else
    miss "Xcode CLI tools"
    MISSING_COUNT=$((MISSING_COUNT + 1))
  fi
else
  check_command "gcc" "gcc"
  check_command "g++" "g++"
  check_command "make" "make"
fi

# ── Summary and install commands ─────────────────────────────────────────────

printf "\n${BOLD}--- Summary ---${RESET}\n"
printf "  Found   : ${GREEN}%d${RESET}\n" "$FOUND_COUNT"
printf "  Missing : ${RED}%d${RESET}\n" "$MISSING_COUNT"

if [[ $MISSING_COUNT -gt 0 ]]; then
  printf "\n${YELLOW}Install missing dependencies:${RESET}\n\n"

  case "$OS" in
    debian)
      cat <<'EOF'
  sudo apt update && sudo apt install -y \
    libgdal-dev libgeos-dev libproj-dev \
    libsndfile1-dev \
    libxml2-dev libglpk-dev \
    build-essential gfortran
EOF
      ;;
    fedora)
      cat <<'EOF'
  sudo dnf install -y \
    gdal-devel geos-devel proj-devel \
    libsndfile-devel \
    libxml2-devel glpk-devel \
    gcc gcc-c++ gcc-gfortran
EOF
      ;;
    arch)
      cat <<'EOF'
  sudo pacman -S --needed \
    gdal geos proj \
    libsndfile \
    libxml2 glpk \
    base-devel gcc-fortran
EOF
      ;;
    macos)
      cat <<'EOF'
  # Install Homebrew if not present: https://brew.sh
  brew install gdal geos proj libsndfile libxml2 glpk
  xcode-select --install   # if Xcode CLI tools are missing
EOF
      ;;
    windows)
      cat <<'EOF'
  # 1. Install Rtools: https://cran.r-project.org/bin/windows/Rtools/
  #    (includes gcc, make, and most C libraries)
  #
  # 2. Most R packages install as pre-compiled binaries on Windows.
  #    If sf or terra fail, install from binary:
  #      install.packages("sf", type = "binary")
  #      install.packages("terra", type = "binary")
  #
  # 3. For conda users:
  #      conda install -c conda-forge gdal geos proj libsndfile
EOF
      ;;
    *)
      printf "  Could not detect your package manager.\n"
      printf "  Install: GDAL, GEOS, PROJ, libsndfile, libxml2, GLPK, and a C/C++ compiler.\n"
      ;;
  esac

  printf "\n${YELLOW}After installing system dependencies, run:${RESET}\n"
  printf "  Rscript setup/install_packages.R --missing\n\n"
  exit 1
else
  printf "\n${GREEN}All system dependencies are present!${RESET}\n"
  printf "You can proceed with: Rscript setup/install_packages.R --missing\n\n"
  exit 0
fi
