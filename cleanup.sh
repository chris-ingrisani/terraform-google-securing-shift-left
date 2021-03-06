#!/bin/bash
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This file will remove all resources built with this blueprint

# Load customer variables
source ./vars.sh
source ./scripts/helper.sh

QUIET="false"

while getopts 'q ': option
do
    case "${option}" in
        q) QUIET="true";;
        *) echo "INVALID Parameter"
    esac
done

# Verify required environment variables are set
echo -e "${FANCY_NONE} Verifying Required Environment Variables"
REQ_ENVS=("GOOGLE_PROJECT_ID" "TF_STATE_BUCKET")
verify_env_vars "${REQ_ENVS}"

# Verify required CLI tools are on PATH used gcloud, terraform, gsutil
echo -e "${FANCY_NONE} Verifying Required CLI tools"
REQUIRED=("gcloud" "terraform" "gsutil")
verify_cli_tools "${REQUIRED}"

# Verify state bucket
echo -e "${FANCY_NONE} Verifying access to Terraform Remote State Bucket"
# shellcheck disable=SC2034
BUCKET=$(gsutil ls -al gs://${TF_STATE_BUCKET} > /dev/null)
if [ $? -gt 0 ]; then
    echo -e "${FANCY_FAIL} Access to Terraform State Bucket failed: $(gsutil ls -al gs://${TF_STATE_BUCKET})"
    exit 1
else
    echo -e "${FANCY_OK} Access to Terraform State Bucket succeeded"
fi

echo -e "${FANCY_NONE} Removing infrastructure"
pushd terraform
    if [[ "${QUIET}" == "true" ]]; then
        terraform destroy -auto-approve
    else
        terraform destroy
    fi
popd
