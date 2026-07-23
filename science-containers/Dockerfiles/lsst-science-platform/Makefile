DEVNAME = sciplat-lab

NAME = images.canfar.net/lsst/$(DEVNAME)
VERSION = latest_daily
DATE := $(shell date '+%Y%m%d')

# CADC-patched packages: EUPS name and setupRequired/setupOptional kind.
# Forks are always ijiraq/lsst_<name>. Install order is Dockerfile order only
# (e.g. resources before daf_butler). To add a package: append here, add
# ARG+RUN in the Dockerfile, and wire the build-arg below / in the workflow.
CADC_PACKAGES = resources daf_butler
CADC_KIND_resources = Required
CADC_KIND_daf_butler = Optional

# resources -> RESOURCES_VER, daf_butler -> DAF_BUTLER_VER
pkg_ver_arg = $(shell echo $(1) | tr '[:lower:]' '[:upper:]')_VER

# EUPS pin from the base image (cache-busts that package's install layer).
# Base image defaults to nobody + SHELL=nologin; loadLSST.bash needs bash and a
# writable HOME for EUPS.
eups-ver:
	@test -n "$(PKG)" || (echo "usage: make eups-ver PKG=resources KIND=Required" >&2; exit 1)
	@docker run --rm -u 0 -e SHELL=bash -e HOME=/tmp --entrypoint bash lsstsqre/sciplat-lab:$(VERSION) -c '\
		source /opt/lsst/software/stack/loadLSST.bash >/dev/null 2>&1 && \
		setup lsst_distrib >/dev/null 2>&1 && \
		TABLE=$$(eups list -s -d lsst_distrib)/ups/lsst_distrib.table && \
		awk "/setup$(KIND)\\($(PKG)/ { gsub(/)/, \"\", \$$NF); print \$$NF; exit }" "$$TABLE"'

resources-ver:
	@$(MAKE) -s eups-ver PKG=resources KIND=$(CADC_KIND_resources)

daf-butler-ver:
	@$(MAKE) -s eups-ver PKG=daf_butler KIND=$(CADC_KIND_daf_butler)

RESOURCES_VER ?= $(shell $(MAKE) -s resources-ver)
DAF_BUTLER_VER ?= $(shell $(MAKE) -s daf-butler-ver)

BUILD_ARGS = \
	--build-arg VERSION=$(VERSION) \
	$(foreach p,$(CADC_PACKAGES),--build-arg $(call pkg_ver_arg,$(p))=$($(call pkg_ver_arg,$(p))))

# Optional Buildx cache. CI sets:
#   CACHE_FROM=type=gha CACHE_TO=type=gha,mode=max
# Leave unset locally (type=gha only works on GitHub Actions runners).
CACHE_FROM ?=
CACHE_TO ?=
CACHE_FLAGS =
ifneq ($(CACHE_FROM),)
CACHE_FLAGS += --cache-from=$(CACHE_FROM)
endif
ifneq ($(CACHE_TO),)
CACHE_FLAGS += --cache-to=$(CACHE_TO)
endif

# Optional buildx metadata (CI uses this to capture the pushed digest).
METADATA_FILE ?=
METADATA_FLAGS =
ifneq ($(METADATA_FILE),)
METADATA_FLAGS += --metadata-file=$(METADATA_FILE)
endif

BUILDX_TAGS = \
	-t $(NAME):$(DATE) \
	-t $(NAME):$(VERSION)

# Shared buildx invocation pieces (target/file/context differ per recipe).
BUILDX_BASE = docker buildx build \
	--platform linux/amd64 \
	$(BUILD_ARGS) \
	$(CACHE_FLAGS) \
	$(BUILDX_TAGS) \
	-f Dockerfile .

# Local image only (--load). SBOM/provenance attestations are not retained in
# the default Docker image store, so they are omitted here on purpose.
build: dependencies Dockerfile
	$(BUILDX_BASE) \
		--target deploy \
		--load \
		.

# Build, attach SBOM + provenance, and push. Requires prior `docker login`.
# Attestations only reach the registry when pushed via buildx (not docker push).
deploy: dependencies Dockerfile
	$(BUILDX_BASE) \
		--target deploy \
		--sbom=true \
		--provenance=mode=max \
		$(METADATA_FLAGS) \
		--push \
		.

dev: dependencies Dockerfile
	$(BUILDX_BASE) \
		--target dev \
		--load \
		.

dependencies:

init:
	mkdir -p build

.PHONY: build deploy dev clean eups-ver resources-ver daf-butler-ver
clean:
	\rm -rf build
