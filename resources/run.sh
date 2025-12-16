#! /usr/bin/bash
set -e -x

sed -i "s|^export OPENSHIFT_RELEASE_IMAGE=.*|export OPENSHIFT_RELEASE_IMAGE=$1|" config_rr.sh
cp config_rr.sh dev-scripts/

pushd /home/rr/dev-scripts
make clean
make requirements configure build_installer ironic install_config
 
mkdir -p ocp/ostest/manifests
cp ~/extra_manifests_no_overlay_eBGP/*yaml ocp/ostest/manifests/

LOGS_FILE=ocp_run_$(date +%Y%m%d_%H%M%S).logs
nohup make ocp_run > $LOGS_FILE &

FULL_PATH_LOGS=$(realpath $LOGS_FILE)
echo -e "Installation has started. Logging to:\n\t$FULL_PATH_LOGS"
popd

set +x
