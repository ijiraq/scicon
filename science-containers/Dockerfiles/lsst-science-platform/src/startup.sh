#!/bin/bash
set -a
export SHELL="bash"
export CPU_LIMIT="${OMP_NUM_THREADS:-1}"
export RUNNING_INSIDE_JUPYTERLAB="TRUE"
export EXTERNAL_INSTANCE_URL="https://data.lsst.cloud"
export DAF_BUTLER_REPOSITORY_INDEX="https://www.canfar.net/storage/arc/file/projects/LSST/cadc_repositories.yaml"
export TMPDIR="/tmp"

# use the cadc remote butler which is connected to Storage Inventory
export DAF_BUTLER_SERVER_GAFAELFAWR_URL=DISABLED
export DAF_BUTLER_SERVER_AUTHENTICATION=cadc

# initialize the LSST path
. /etc/profile
.  /opt/lsst/software/stack/loadLSST.bash

# Profile and EUPS may enable errexit. Token and discovery failures must not
# skip launching Jupyter. Firefly is started on demand from the Lab launcher.
set +e

# /usr/bin/jupyter is the wrapper that re-enters this script. Exec the stack
# or JupyterLab venv binary so that call cannot loop.
resolve_jupyter() {
  local dir candidate real wrapper
  local IFS=:
  wrapper=$(readlink -f /usr/bin/jupyter 2>/dev/null || printf '%s' /usr/bin/jupyter)
  for dir in $PATH; do
    [ -n "$dir" ] || continue
    candidate="${dir%/}/jupyter"
    [ -x "$candidate" ] && [ -f "$candidate" ] || continue
    real=$(readlink -f "$candidate" 2>/dev/null || printf '%s' "$candidate")
    if [ "$real" != "$wrapper" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  candidate=/usr/local/share/jupyterlab/venv/bin/jupyter
  if [ -x "$candidate" ]; then
    real=$(readlink -f "$candidate" 2>/dev/null || printf '%s' "$candidate")
    if [ "$real" != "$wrapper" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi
  return 1
}

# Ensure Welcome.md is visible under Skaha's notebook root (/). Prefer the
# ARC project path (Argo / shared storage); fall back to the image copy.
ensure_welcome() {
  local dest=/arc/projects/LSST/Welcome.md
  local baked=/usr/local/share/jupyterlab/etc/Welcome.md
  if [ -f "$dest" ]; then
    printf '%s\n' "$dest"
    return 0
  fi
  if [ -f "$baked" ]; then
    mkdir -p "$(dirname "$dest")" 2>/dev/null || true
    if cp "$baked" "$dest" 2>/dev/null; then
      printf '%s\n' "$dest"
      return 0
    fi
    printf '%s\n' "$baked"
    return 0
  fi
  return 1
}

# Session setup (token + discovery) only when launching Jupyter. Image builds
# also call `/skaha/startup.sh pip|jupyter …` as root; running discovery then
# leaves root-owned files under /etc/nublado that Skaha UIDs cannot overwrite
# (dirs are 1777 sticky, so other users cannot delete root's files either).
is_jupyter_launch() {
  case "${1:-}" in
    jupyter|/usr/bin/jupyter) return 0 ;;
    *) return 1 ;;
  esac
}

if is_jupyter_launch "$@"; then
  mkdir -p /etc/nublado/secrets /etc/nublado/discovery
  chmod 1777 /etc/nublado /etc/nublado/discovery /etc/nublado/secrets 2>/dev/null || true

  # Authenticate to CADC and publish the token where RSPDiscovery looks for it:
  #   1) /etc/nublado/secrets/token  (preferred)
  #   2) NUBLADO_TOKEN / ACCESS_TOKEN environment variables
  [ -f ~/.ssl/cadcproxy.pem ] || canfar auth login || \
    echo "WARNING: canfar auth login failed" >&2
  if [ -f ~/.ssl/cadcproxy.pem ]; then
    TOKEN=$(curl -fsS --max-time 30 -E ~/.ssl/cadcproxy.pem \
      "https://ws-cadc.canfar.net/ac/authorize?response_type=token") || true
    if [ -n "${TOKEN:-}" ]; then
      (umask 077; printf '%s\n' "$TOKEN" > /etc/nublado/secrets/token) || \
        echo "WARNING: failed to write /etc/nublado/secrets/token" >&2
      export NUBLADO_TOKEN="$TOKEN"
      export ACCESS_TOKEN="$TOKEN"
      export CADC_TOKEN="$TOKEN"
    else
      echo "WARNING: failed to obtain a CADC token" >&2
    fi
  fi

  # Resolve CADC IVOA resource-caps into RSPDiscovery's Nublado discovery file.
  # Dataset map lives on ARC (Argo CD) and is fetched over HTTPS.
  # Override with CANFAR_DATASET_MAP (https:// URL or local path) to test.
  python /skaha/populate_discovery.py \
    --map "${CANFAR_DATASET_MAP:-https://www.canfar.net/storage/arc/file/projects/LSST/cadc_dataset_map.yaml}" \
    || echo "WARNING: failed to populate /etc/nublado/discovery/v1.json" >&2

  if JUPYTER_BIN=$(resolve_jupyter); then
    shift
    filtered=()
    for arg in "$@"; do
      case "$arg" in
        --LabApp.app_name|--LabApp.app_name=*|--LabApp.default_url|--LabApp.default_url=*)
          ;;
        *)
          filtered+=("$arg")
          ;;
      esac
    done
    set -- "$JUPYTER_BIN" "${filtered[@]}"
    if WELCOME_PATH=$(ensure_welcome); then
      # Skaha notebook root is /; tree path is absolute-from-root without leading /.
      WELCOME_TREE=${WELCOME_PATH#/}
      set -- "$@" "--LabApp.default_url=/lab/tree/${WELCOME_TREE}"
    fi
  else
    echo "WARNING: no jupyter binary other than /usr/bin/jupyter" >&2
  fi
fi

exec "$@"
