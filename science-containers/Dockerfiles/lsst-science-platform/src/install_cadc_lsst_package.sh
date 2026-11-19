#!/bin/bash
# Install a CADC-patched LSST package from an ijiraq fork.
#
# Convention (same for every package):
#   fork:     https://github.com/ijiraq/${FORK_REPO}
#             default FORK_REPO=lsst_<package> (override for e.g. obs_subaru)
#   upstream: https://github.com/lsst/<package>
#   branch:   $FEATURE_BRANCH (default: cadc_datastore), rebased onto the
#             per-package EUPS pin from lsst_distrib.table when present, else
#             the version currently setup by lsst_distrib
#             (setupRequired/setupOptional line for this package — not the
#             lsst_distrib metapackage version itself).
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

# Individual package pin from the metapackage table (e.g. setupRequired(resources …)).
# Instrument packages like obs_subaru are listed under lsst_obs, not lsst_distrib;
# fall back to the setup product's install directory name (the EUPS version).
# Do not parse `eups list -s` columns — those are ambiguous and can match
# related products (e.g. obs_subaru_data vs obs_subaru).
TABLE="$(eups list -s -d lsst_distrib)/ups/lsst_distrib.table"
PINNED="$(awk -v pkg="$PACKAGE" -v kind="$SETUP_KIND" \
    'index($0, "setup" kind "(" pkg) { gsub(/)/, "", $NF); print $NF; exit }' \
    "$TABLE")"
if [ -z "$PINNED" ]; then
    PINNED="$(basename "$(eups list -s -d "$PACKAGE")")"
fi
test -n "$PINNED"
echo "EUPS pin for ${PACKAGE}: ${PINNED}"

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

# #region agent log
_dbg() { echo "DEBUG_AGENT_LOG $1"; }
_RESOLVED=false
_dbg "{\"sessionId\":\"b04648\",\"runId\":\"${DEBUG_RUN_ID:-post-fix}\",\"hypothesisId\":\"A\",\"location\":\"install_cadc_lsst_package.sh:resolve-pin\",\"message\":\"pin resolve inputs\",\"data\":{\"package\":\"${PACKAGE}\",\"pinned\":\"${PINNED}\",\"upstreamCommit\":\"${UPSTREAM_COMMIT}\",\"commitLen\":${#UPSTREAM_COMMIT}},\"timestamp\":$(date +%s000)}"
# #endregion

PIN_FULL="$(git rev-parse --verify "${UPSTREAM_COMMIT}^{commit}" 2>/dev/null || true)"
if [ -n "$PIN_FULL" ]; then
    _RESOLVED=true
fi

# #region agent log
_dbg "{\"sessionId\":\"b04648\",\"runId\":\"${DEBUG_RUN_ID:-post-fix}\",\"hypothesisId\":\"D\",\"location\":\"install_cadc_lsst_package.sh:resolve-pin\",\"message\":\"rev-parse after fetch main\",\"data\":{\"upstreamCommit\":\"${UPSTREAM_COMMIT}\",\"pinFull\":\"${PIN_FULL}\",\"resolved\":${_RESOLVED}},\"timestamp\":$(date +%s000)}"
# #endregion

if [ -z "$PIN_FULL" ]; then
    if [[ "$UPSTREAM_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
        # #region agent log
        _dbg "{\"sessionId\":\"b04648\",\"runId\":\"${DEBUG_RUN_ID:-post-fix}\",\"hypothesisId\":\"A\",\"location\":\"install_cadc_lsst_package.sh:resolve-pin\",\"message\":\"fetching full sha fallback\",\"data\":{\"sha\":\"${UPSTREAM_COMMIT}\"},\"timestamp\":$(date +%s000)}"
        # #endregion
        git fetch --no-tags upstream "$UPSTREAM_COMMIT"
        PIN_FULL="$(git rev-parse --verify "${UPSTREAM_COMMIT}^{commit}")"
    else
        # #region agent log
        _dbg "{\"sessionId\":\"b04648\",\"runId\":\"${DEBUG_RUN_ID:-post-fix}\",\"hypothesisId\":\"B\",\"location\":\"install_cadc_lsst_package.sh:resolve-pin\",\"message\":\"pin not on main and not full sha\",\"data\":{\"upstreamCommit\":\"${UPSTREAM_COMMIT}\"},\"timestamp\":$(date +%s000)}"
        # #endregion
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
