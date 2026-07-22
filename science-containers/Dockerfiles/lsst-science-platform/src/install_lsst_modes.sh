#!/bin/bash
# Install version of lsst packages that have been modified to work in CADC environment
# this is only needed until Rubin accepts our pull request, but DP2 is next week
# and they don't have time right now.

branch=cadc_datastore

. /etc/profile
.  /opt/lsst/software/stack/loadLSST.bash
setup lsst_distrib

# Ensure lsst_distrib is set up (or at least known)
setup lsst_distrib
TABLE="$(eups list -s -d lsst_distrib)/ups/lsst_distrib.table"
# Exact pins for your packages
RESOURCES_VER=$(awk '/setupRequired\(resources/ {print $NF}' "$TABLE" | tr -d ')')
DAF_BUTLER_VER=$(awk '/setupOptional\(daf_butler/ {print $NF}' "$TABLE" | tr -d ')')

start_dir=$(pwd)
git clone -b ${branch} https://github.com/ijiraq/lsst_resources.git  resources
cd resources
setup -r .
scons --no-tests 
scons --no-tests install declare current version=${RESOURCES_VER}
setup resources

cd ${start_dir}
git clone -b ${branch} https://github.com/ijiraq/daf_butler.git  daf_butler
cd daf_butler
setup -r .
scons --no-tests
scons --no-tests install declare current version=${DAF_BUTLER_VER}
setup daf_butler
