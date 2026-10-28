# Welcome to the CANFAR Rubin Science Notebook

This is the **CANFAR** deployment of the Rubin Observatory Science Platform
(RSP) Notebook Aspect. JupyterLab and the LSST Science Pipelines stack run
here the same way they do on the RSP, with CANFAR authentication, storage,
and service discovery wired in at session start.

If you have issues, contact **support@canfar.net**.

---

## What was configured for this session

At startup this container:

1. Loads the LSST Science Pipelines environment from `/opt/lsst/software/stack`.
2. Obtains a **CADC / CANFAR** access token (from your `~/.ssl/cadcproxy.pem`
   certificate) and publishes it where RSP APIs expect it:
   - `/etc/nublado/secrets/token`
   - environment: `NUBLADO_TOKEN`, `ACCESS_TOKEN`, `CADC_TOKEN`
3. Builds **service discovery** for `lsst.rsp.RSPDiscovery` from
   `https://www.canfar.net/storage/arc/file/projects/LSST/cadc_dataset_map.yaml`
   (override with `CANFAR_DATASET_MAP`) into `/etc/nublado/discovery/v1.json`.
4. Points Butler repository aliases at
   `DAF_BUTLER_REPOSITORY_INDEX` →
   `https://www.canfar.net/storage/arc/file/projects/LSST/cadc_repositories.yaml`
   (same file as `/arc/projects/LSST/cadc_repositories.yaml` on ARC).

Firefly is **not** started until you open it from the Lab launcher.
Tutorials are cloned on first use from the Tutorials menu.

---

## Discovery dataset labels (RSPDiscovery)

These labels are registered in discovery for this session (from the dataset
map). Use them with `RSPDiscovery("<label>")`.

| Label | Auth | Notes |
| --- | --- | --- |
| `dp1` | CANFAR (CADC) session token | YouCAT / CAOM / CADC GMS; Butler on CANFAR. HiPS URL is Rubin’s and needs a separate Rubin token. |
| `dp2` | CANFAR (CADC) session token | Same pattern as `dp1` for Data Preview 2. |
| `dp02` | **Rubin** token required | Mirrored URLs on `data.lsst.cloud` (DP0.2). |
| `prompt` | **Rubin** token required | Rubin prompt / alerts APIs. |

### List what is actually available right now

Discovery and Butler aliases can change without rebuilding this image. Get a
**live** listing in a notebook or terminal:

```python
from lsst.rsp import list_datasets, RSPDiscovery
from lsst.daf.butler import Butler

list_datasets()                 # discovery dataset labels
sorted(Butler.get_known_repos())  # Butler repository aliases
```

Example against CANFAR YouCAT / CAOM services (default session token):

```python
discovery = RSPDiscovery("dp2")
tap = discovery.get_tap_client()
```

Rubin-mirrored datasets (`dp02`, `prompt`) and HiPS URLs under `dp1`/`dp2`
point at `data.lsst.cloud` and need a **separate Rubin token**:

```python
import os
rubin = RSPDiscovery("dp02", token=os.environ["RUBIN_TOKEN"])
```

Create Rubin tokens at:
https://rsp.lsst.io/guides/auth/creating-user-tokens.html

---

## Butler repository aliases

Configured via `DAF_BUTLER_REPOSITORY_INDEX` (live list:
`sorted(Butler.get_known_repos())`). Typical aliases:

| Alias | Repository |
| --- | --- |
| `dp1`, `canfar-dp1` | CANFAR Butler for DP1 |
| `dp2`, `canfar-dp2` | CANFAR Butler for DP2 |
| `rubin-dp1` | Rubin `data.lsst.cloud` DP1 (Rubin auth) |
| `rubin-dp2` | Rubin `data.lsst.cloud` DP2 (Rubin auth) |

Example:

```python
from lsst.daf.butler import Butler
butler = Butler("dp2")
```

---

## Firefly

Use the JupyterLab launcher card **Firefly Viewer** (Firefly section). It
starts a CANFAR Firefly session if needed and opens it in a Lab tab.

Image / session name defaults (override with environment variables):

- `CANFAR_FIREFLY_IMAGE` — default `images.canfar.net/skaha/firefly:2025.2`
- `CANFAR_FIREFLY_NAME` — default `firefly`

---

## Tutorials

Use the **Tutorials** menu. Notebooks are shallow-cloned on first use from
`CANFAR_TUTORIALS_REPO` (default
`https://github.com/rubin-dp0/tutorial-notebooks@prod`) into
`CANFAR_TUTORIALS_DEST` under your home (default `notebooks/tutorials`).

---

## Documentation

| Resource | URL |
| --- | --- |
| LSST Science Pipelines | https://pipelines.lsst.io |
| Rubin Science Platform | https://rsp.lsst.io |
| Nublado / Notebook Aspect | https://repertoire.lsst.io/user-guide/nublado.html |
| CANFAR support | support@canfar.net |

The Rubin Observatory Science Pipelines environment is in:

```text
/opt/lsst/software/stack
```

This welcome page lives at `/arc/projects/LSST/Welcome.md` (also shipped in
the image under `/usr/local/share/jupyterlab/etc/Welcome.md` as a fallback).
