#!/bin/bash
# Print the EUPS pin for a package from the running LSST stack.
# Exact product-name match only (obs_subaru must not resolve to obs_subaru_data).
set -e
PACKAGE="${1:?package}"
SETUP_KIND="${2:?Required or Optional}"
export HOME="${HOME:-/tmp}"
export SHELL="${SHELL:-/bin/bash}"

source /opt/lsst/software/stack/loadLSST.bash >/dev/null 2>&1
setup lsst_distrib >/dev/null 2>&1

pin_from_table() {
    local table="$1"
    [ -f "$table" ] || return 0
    awk -v pkg="$PACKAGE" -v kind="$SETUP_KIND" '
        $0 ~ ("setup" kind "\\(" pkg "([ )]|$)") {
            gsub(/)/, "", $NF); print $NF; exit
        }' "$table"
}

TABLE="$(eups list -s -d lsst_distrib)/ups/lsst_distrib.table"
VER="$(pin_from_table "$TABLE")"
if [ -z "$VER" ]; then
    setup lsst_obs >/dev/null 2>&1 || true
    LSST_OBS_DIR="$(eups list -s -e -d lsst_obs 2>/dev/null || true)"
    if [ -n "$LSST_OBS_DIR" ]; then
        VER="$(pin_from_table "${LSST_OBS_DIR}/ups/lsst_obs.table")"
    fi
fi
if [ -z "$VER" ]; then
    VER="$(basename "$(eups list -s -e -d "$PACKAGE")")"
fi
test -n "$VER"
echo "$VER"
