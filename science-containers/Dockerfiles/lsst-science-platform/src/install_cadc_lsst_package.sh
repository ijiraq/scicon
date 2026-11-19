#!/bin/bash
# Install a CADC-patched LSST package from an ijiraq fork.
#
# Convention (same for every package):
#   fork:     https://github.com/ijiraq/${FORK_REPO}
#             default FORK_REPO=lsst_<package> (override for e.g. obs_subaru)
#   upstream: https://github.com/lsst/<package>
#   branch:   $FEATURE_BRANCH (default: cadc_datastore), rebased onto the
#             per-package EUPS pin from lsst_distrib.table or lsst_obs.table
#             (exact product name; never substring-match e.g. obs_subaru_data).
#
# Usage:
#   FEATURE_BRANCH=cadc_datastore \
#     install_cadc_lsst_package.sh <package> <Required|Optional>
#   FEATURE_BRANCH=tickets/eb-gri-nh FORK_REPO=obs_subaru \
#     install_cadc_lsst_package.sh obs_subaru Required
#
# Note: do not enable `set -u` before loadLSST/setup — conda/eups activate
# scripts reference unset vars (EUPS_PATH, DYLD_LIBRARY_PATH, etc.).
set -e
# BuildKit RUN often leaves HOME unset; EUPS setup expands ${HOME}/.cargo/.
export HOME="${HOME:-/root}"
export SHELL="${SHELL:-/bin/bash}"

PACKAGE="${1:?package name required (e.g. resources, daf_butler)}"
SETUP_KIND="${2:?Required or Optional (setupRequired/setupOptional in table)}"
FEATURE_BRANCH="${FEATURE_BRANCH:-cadc_datastore}"
FORK_REPO="${FORK_REPO:-lsst_${PACKAGE}}"

echo "Installing ${PACKAGE} from ijiraq/${FORK_REPO}@${FEATURE_BRANCH} (kind=${SETUP_KIND})"

source /opt/lsst/software/stack/loadLSST.bash
setup lsst_distrib

# Individual package pin from a metapackage table (setupRequired/setupOptional).
# Match the product name exactly — EUPS and naive substring searches both match
# longer names (obs_subaru → obs_subaru_data → wrong git SHA / wrong pin).
# Instrument packages live in lsst_obs.table, not lsst_distrib.table.
_pin_from_table() {
    local table="$1"
    [ -f "$table" ] || return 0
    awk -v pkg="$PACKAGE" -v kind="$SETUP_KIND" '
        $0 ~ ("setup" kind "\\(" pkg "([ )]|$)") {
            gsub(/)/, "", $NF); print $NF; exit
        }' "$table"
}

PIN_SOURCE=""
TABLE="$(eups list -s -d lsst_distrib)/ups/lsst_distrib.table"
PINNED="$(_pin_from_table "$TABLE")"
if [ -n "$PINNED" ]; then
    PIN_SOURCE="lsst_distrib.table"
fi
if [ -z "$PINNED" ]; then
    # lsst_obs is setupOptional under lsst_distrib; ensure its table is visible.
    setup lsst_obs >/dev/null 2>&1 || true
    LSST_OBS_DIR="$(eups list -s -e -d lsst_obs 2>/dev/null || true)"
    if [ -n "$LSST_OBS_DIR" ] && [ -f "${LSST_OBS_DIR}/ups/lsst_obs.table" ]; then
        PINNED="$(_pin_from_table "${LSST_OBS_DIR}/ups/lsst_obs.table")"
        if [ -n "$PINNED" ]; then
            PIN_SOURCE="lsst_obs.table"
        fi
    fi
fi
if [ -z "$PINNED" ]; then
    # Exact product only (-e); without it, eups list matches obs_subaru_data too.
    EUPS_DIR="$(eups list -s -e -d "$PACKAGE" 2>/dev/null || true)"
    if [ -n "$EUPS_DIR" ]; then
        PINNED="$(basename "$EUPS_DIR")"
        PIN_SOURCE="eups-exact"
    fi
fi
test -n "$PINNED"
echo "EUPS pin for ${PACKAGE}: ${PINNED} (source=${PIN_SOURCE})"

UPSTREAM_COMMIT="$(echo "$PINNED" | sed -E 's/^g//; s/\+.*//')"
SRC="/tmp/${PACKAGE}"

echo "Cloning https://github.com/ijiraq/${FORK_REPO}.git (${FEATURE_BRANCH})"
git clone \
    --branch "$FEATURE_BRANCH" \
    --single-branch \
    "https://github.com/ijiraq/${FORK_REPO}.git" \
    "$SRC"
cd "$SRC"
git remote add upstream "https://github.com/lsst/${PACKAGE}.git"
# Fetch main so the EUPS pin (usually an ancestor) is in the object DB.
# Do NOT `git fetch upstream <short-sha>`: GitHub rejects abbreviated SHAs as
# remote refs ("couldn't find remote ref"). Fetch-by-SHA needs the full 40-char id.
git fetch --no-tags upstream main

PIN_FULL="$(git rev-parse --verify "${UPSTREAM_COMMIT}^{commit}" 2>/dev/null || true)"
if [ -z "$PIN_FULL" ]; then
    if [[ "$UPSTREAM_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
        git fetch --no-tags upstream "$UPSTREAM_COMMIT"
        PIN_FULL="$(git rev-parse --verify "${UPSTREAM_COMMIT}^{commit}")"
    else
        echo "ERROR: EUPS pin commit ${UPSTREAM_COMMIT} not found on upstream/main" >&2
        exit 1
    fi
fi

# EUPS pin is a specific upstream commit (often behind main). Rebase the
# feature branch onto that pin — do not require pin == upstream/main HEAD.
git merge-base --is-ancestor "$PIN_FULL" upstream/main
echo "Rebasing ${FEATURE_BRANCH} onto upstream ${PIN_FULL}"
git -c user.name="Container Build" \
    -c user.email="container-build@localhost" \
    rebase "$PIN_FULL"

setup -r .
scons --no-tests
scons --no-tests install declare current "version=${PINNED}"
setup "$PACKAGE"
echo "Installed ${PACKAGE} ${PINNED}"
