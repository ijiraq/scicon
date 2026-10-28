# This Dockerfile is used to build the LSST Science Platform container
# This is currently an ALMA LINUX distro
# BASE_IMAGE should be a digest-pinned ref (lsstsqre/sciplat-lab@sha256:...) so
# the EUPS pins probed by Make match the image Buildx actually builds FROM.
ARG BASE_IMAGE=lsstsqre/sciplat-lab:latest_daily
FROM ${BASE_IMAGE} AS deploy

# The RSP removes the passwd and group files 
# but that makes adding software fail. Add back
# a default set of system users so we can augment the container
USER 0:0
# BuildKit does not always set HOME for RUN; EUPS/loadLSST need a writable HOME.
ENV HOME=/root \
    SHELL=/bin/bash
COPY src/passwd /etc/passwd
COPY src/group /etc/group
RUN cat /var/lib/dpkg/statoverride
RUN rm /var/lib/dpkg/statoverride
RUN rm /var/lib/dpkg/lock
RUN dpkg --configure -a
RUN apt-get update
RUN apt-get -f install
RUN sed -i -e 's/http:\/\//https:\/\//g' /etc/apt/sources.list.d/debian.sources
# Add xterm so this can be run on Desktop App 
RUN apt-get install -y libx11-dev
RUN apt-get install -y xterm
RUN apt-get install -y git-lfs
RUN apt install -y graphviz
RUN apt-get clean

# install ds9, no packages and not on lsst platform by default
# RUN curl https://ds9.si.edu/download/centos7/ds9.centos7.8.5.tar.gz | tar -zx -f - -C /usr/bin/
# RUN curl https://ds9.si.edu/download/centos9x86/ds9.centos9x86.8.7b1.tar.gz | tar -zx -f - -C /usr/bin/
RUN curl https://ds9.si.edu/download/centos-stream-9_x86_64/ds9.centos-stream-9_x86_64.8.8.tar.gz | tar -zx -f - -C /usr/bin
RUN curl https://ds9.si.edu/download/centos-stream-9_x86_64/xpa.centos-stream-9_x86_64.2.2.1.tar.gz | tar -zx -f - -C /usr/bin


# Add our own MOTD and the JupyterLab welcome page (also under ARC path so
# LabApp.default_url=/lab/tree/arc/projects/LSST/Welcome.md works when the
# notebook root is /). Production ARC mounts may overlay /arc; keep a baked
# fallback and sync the same file via Argo (arc-projects-LSST/Welcome.md).
COPY src/rsp_notice /usr/local/share/jupyterlab/etc/rsp_notice
COPY src/Welcome.md /usr/local/share/jupyterlab/etc/Welcome.md
RUN mkdir -p /arc/projects/LSST \
 && cp /usr/local/share/jupyterlab/etc/Welcome.md /arc/projects/LSST/Welcome.md

# The skaha platform expects to find 'jupyter' in the path
# but we need to activate the correct conda first.
# add a startup script that initializes the environment correctly
RUN mkdir /skaha
COPY src/startup.sh /skaha/startup.sh
RUN chmod +x /skaha/startup.sh
COPY src/launch_firefly_on_canfar.py /skaha/launch_firefly_on_canfar.py
COPY src/populate_discovery.py /skaha/populate_discovery.py
RUN chmod +x /skaha/populate_discovery.py
COPY src/jupyter /usr/bin/jupyter
# cadc_dataset_map.yaml / cadc_repositories.yaml are NOT the only ARC files;
# Welcome.md is baked above as a bootstrap copy. Dataset map + Butler index
# remain Argo-deployed (see arc-projects-LSST/README.md).

# Writable Nublado discovery/token paths used by lsst.rsp.RSPDiscovery.
# Skaha sessions run as arbitrary UIDs, so these dirs must be world-writable
# and must not contain root-owned files left from the image build (sticky 1777
# prevents other UIDs from deleting/overwriting root's files).
RUN mkdir -p /etc/nublado/discovery /etc/nublado/secrets \
 && chmod 1777 /etc/nublado /etc/nublado/discovery /etc/nublado/secrets

# CANFAR Lab UI defaults (override at deploy without rebuilding the extension).
# Tutorials are cloned on first menu use; Firefly is started from the launcher.
ENV CANFAR_TUTORIALS_REPO=https://github.com/rubin-dp0/tutorial-notebooks@prod \
    CANFAR_TUTORIALS_DEST=notebooks/tutorials \
    CANFAR_FIREFLY_IMAGE=images.canfar.net/skaha/firefly:2025.2 \
    CANFAR_FIREFLY_NAME=firefly

# Some items to make this a better experience on CANFAR. Everything Jupyter
# runs from the lsst-scipipe conda env (startup.sh resolves that `jupyter`),
# so all Lab/server extensions must be installed there, not in the
# /usr/local/share/jupyterlab/venv the upstream RSP uses.
#
# canfar_lab_extensions (Firefly launcher + Tutorials menu) is a prebuilt
# labextension wheel published by https://github.com/ijiraq/canfar_lab_extensions;
# no node/jlpm runs here.
ARG CANFAR_LAB_EXT_VERSION=0.1.1
# canfar comes from PyPI as a dependency of canfar_lab_extensions (Firefly /
# Skaha client). Discovery no longer needs canfar.storage; the dataset map is
# fetched over HTTPS.
RUN /skaha/startup.sh pip install --no-cache-dir cadctap cadcdata vos \
    safir lsdb \
    "https://github.com/ijiraq/canfar_lab_extensions/releases/download/v${CANFAR_LAB_EXT_VERSION}/canfar_lab_extensions-${CANFAR_LAB_EXT_VERSION}-py3-none-any.whl"

# Verify the extension is visible to the jupyter that startup.sh will exec.
RUN /skaha/startup.sh jupyter server extension list 2>&1 | grep -q "canfar_lab_extensions.*enabled" \
 && /skaha/startup.sh jupyter labextension list 2>&1 | grep -q "canfar_lab_extensions.*enabled.*OK"

# Firefly's URL only exists after the Lab launcher starts it, so kernels
# (including restarted ones) cannot get it from their launch environment.
# Load the kernel-side sync so lsst.display.firefly sees FIREFLY_URL.
RUN /skaha/startup.sh bash -lc '\
  D=$(python -c "import sys; print(sys.prefix)")/etc/ipython \
  && mkdir -p "$D" \
  && printf "%s\n" "c.InteractiveShellApp.extensions.append(\"canfar_lab_extensions.kernel\")" >> "$D/ipython_kernel_config.py" \
  && python -c "import canfar_lab_extensions.kernel"'

# Brand LabApp.app_name (not a CLI trait in JL 4.x). A .pth auto-imports the
# module into the lsst-scipipe env so the browser title becomes
# "Rubin Science Notebook" without --LabApp.app_name=... (which TraitErrors).
COPY src/canfar_jupyterlab_branding.py /tmp/canfar_jupyterlab_branding.py
RUN /skaha/startup.sh bash -lc '\
  SP=$(python -c "import sysconfig; print(sysconfig.get_paths()[\"purelib\"])") \
  && cp /tmp/canfar_jupyterlab_branding.py "$SP/canfar_jupyterlab_branding.py" \
  && printf "%s\n" "import canfar_jupyterlab_branding" > "$SP/canfar_jupyterlab_branding.pth" \
  && python -c "import jupyterlab.labapp as m; assert m.LabApp.app_name == \"Rubin Science Notebook\", m.LabApp.app_name" \
  && rm -f /tmp/canfar_jupyterlab_branding.py'

# Drop any discovery/token files that earlier `/skaha/startup.sh …` steps may
# have written as root (before session-only gating). Session UIDs need empty,
# sticky-writable dirs so they can create v1.json / token themselves.
RUN rm -f /etc/nublado/discovery/* /etc/nublado/secrets/* \
 && chmod 1777 /etc/nublado /etc/nublado/discovery /etc/nublado/secrets
WORKDIR /tmp
COPY src/install_cadc_lsst_package.sh /tmp/install_cadc_lsst_package.sh
RUN chmod +x /tmp/install_cadc_lsst_package.sh

# CADC-patched LSST packages from ijiraq/lsst_<package> forks.
# Each package: feature branch rebased onto that package's EUPS pin from
# lsst_distrib.table. *_VER build-args are cache keys only (from Make probe);
# the install script always reads the pin from this image.
# Install in dependency order (resources before daf_butler).
ARG FEATURE_BRANCH=cadc_datastore

ARG RESOURCES_VER
RUN echo "resources cache key=${RESOURCES_VER}" && \
    FEATURE_BRANCH="$FEATURE_BRANCH" \
    /tmp/install_cadc_lsst_package.sh resources Required

ARG DAF_BUTLER_VER
RUN echo "daf_butler cache key=${DAF_BUTLER_VER}" && \
    FEATURE_BRANCH="$FEATURE_BRANCH" \
    /tmp/install_cadc_lsst_package.sh daf_butler Optional

# This is just for when using this as standalong container
WORKDIR /
ENTRYPOINT ["/skaha/startup.sh"]

FROM deploy AS dev
RUN echo "Adding a user to run local developement"
RUN mkdir -p /arc/home
RUN groupadd -g 1001 testuser
RUN useradd -u 1001 -g 1001 -s /bin/bash -d /arc/home/testuser -m testuser
WORKDIR /arc/home/testuser
USER testuser
# Add test stuff here if needed.
