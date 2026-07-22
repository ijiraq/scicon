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

deploy: dependencies Dockerfile
	docker build \
		--target deploy \
		$(BUILD_ARGS) \
		-t $(NAME):$(DATE) -f Dockerfile .
	docker push $(NAME):$(DATE)

dev: dependencies Dockerfile
	docker build \
		--target dev \
		$(BUILD_ARGS) \
		-t $(NAME):$(DATE) -f Dockerfile .

dependencies:

init:
	mkdir -p build

.PHONY: clean eups-ver resources-ver daf-butler-ver
clean:
	\rm -rf build
