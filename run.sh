#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Script Configuration ---
PROJECT_ID=""
ACTION=""
STAGE=""

# --- Helper Functions ---
info() {
  echo " "
  echo "--------------------------------------------------"
  echo "--> $1"
  echo "--------------------------------------------------"
}

usage() {
  echo "Usage: $0 --project <PROJECT_ID> --[apply|destroy] [prerun|psc|mig|lb|all]"
  echo " "
  echo "Arguments:"
  echo "  --project <PROJECT_ID>    : Your Google Cloud Project ID (Required)."
  echo "  --apply <stage>           : Apply the specified stage."
  echo "  --destroy <stage>         : Destroy the specified stage."
  echo " "
  echo "Stages: [prerun, psc, mig, lb, all]"
  echo " "
  echo "Example: $0 --project my-gcp-project --apply all"
  exit 1
}

check_dependency() {
  local stage_dir="$1"
  local stage_name="$2"
  local stage_flag="$3"

  # Check if the state file for the dependency exists and is not empty
  if [ ! -f "${stage_dir}/terraform.tfstate" ] || [ ! -s "${stage_dir}/terraform.tfstate" ]; then
    echo " "
    echo "ERROR: Prerequisite stage '${stage_name}' has not been successfully applied." >&2
    echo "The state file at '${stage_dir}/terraform.tfstate' is missing or empty." >&2
    echo "Please run './run.sh --project ${PROJECT_ID} --apply ${stage_flag}' first." >&2
    exit 1
  fi
}

# --- Deployment Functions (in order of execution) ---

deploy_prerun() {
  info "Stage 0: Deploying Pre-run (Apigee Core)"
  ( # Run in a subshell to avoid changing the script's directory
    cd 0_pre_run
    terraform init
    TF_VAR_project_id=$PROJECT_ID terraform apply -auto-approve
  )
}

deploy_psc() {
  check_dependency "0_pre_run" "Pre-run" "prerun"
  info "Stage 1.0: Deploying Northbound PSC Endpoint"
  
  # Read output directly from the dependency's state
  local apigee_sa
  apigee_sa=$(cd 0_pre_run && terraform output -raw apigee_service_attachment)

  (
    cd 1_northbound/0_psc_endpoint
    terraform init
    # Pass the output from the previous step as a TF_VAR for this command
    TF_VAR_apigee_service_attachment=$apigee_sa TF_VAR_project_id=$PROJECT_ID terraform apply -auto-approve
  )
}

deploy_mig() {
  check_dependency "1_northbound/0_psc_endpoint" "PSC Endpoint" "psc"
  info "Stage 1.1: Deploying Northbound MIG"

  local psc_neg_name
  psc_neg_name=$(cd 1_northbound/0_psc_endpoint && terraform output -raw psc_neg_name)

  (
    cd 1_northbound/1_mig
    terraform init
    TF_VAR_psc_neg_name=$psc_neg_name TF_VAR_project_id=$PROJECT_ID terraform apply -auto-approve
  )
}

deploy_lb() {
  check_dependency "1_northbound/1_mig" "MIG" "mig"
  info "Stage 1.2: Deploying Northbound Load Balancer"

  local mig_instance_group
  mig_instance_group=$(cd 1_northbound/1_mig && terraform output -raw instance_group_name)
  
  (
    cd 1_northbound/2_load_balancer
    terraform init
    TF_VAR_mig_instance_group=$mig_instance_group TF_VAR_project_id=$PROJECT_ID terraform apply -auto-approve
  )
}


# --- Destroy Functions (in REVERSE order of execution) ---

destroy_lb() {
  info "Destroying Northbound Load Balancer"
  (cd 1_northbound/2_load_balancer && terraform destroy -auto-approve)
}

destroy_mig() {
  info "Destroying Northbound MIG"
  (cd 1_northbound/1_mig && terraform destroy -auto-approve)
}

destroy_psc() {
  info "Destroying Northbound PSC Endpoint"
  (cd 1_northbound/0_psc_endpoint && terraform destroy -auto-approve)
}

destroy_prerun() {
  info "Destroying Pre-run (Apigee Core)"
  (cd 0_pre_run && terraform destroy -auto-approve)
}


# --- Main Execution Logic ---

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --project) PROJECT_ID="$2"; shift; shift;;
    --apply) ACTION="apply"; STAGE="$2"; shift; shift;;
    --destroy) ACTION="destroy"; STAGE="$2"; shift; shift;;
    *) usage;;
  esac
done

# Validate inputs
if [ -z "$PROJECT_ID" ] || [ -z "$ACTION" ] || [ -z "$STAGE" ]; then
  echo "Error: Missing required arguments." >&2
  usage
fi

# Export the Project ID so Terraform can access it in all stages
export TF_VAR_project_id=$PROJECT_ID
info "Using Project ID: $PROJECT_ID"

# Execute the requested action and stage
if [ "$ACTION" == "apply" ]; then
  case $STAGE in
    prerun) deploy_prerun ;;
    psc)    deploy_psc ;;
    mig)    deploy_mig ;;
    lb)     deploy_lb ;;
    all)
      deploy_prerun
      deploy_psc
      deploy_mig
      deploy_lb
      ;;
    *) usage ;;
  esac
  info "Apply Complete!"

elif [ "$ACTION" == "destroy" ]; then
  case $STAGE in
    lb)     destroy_lb ;;
    mig)    destroy_mig ;;
    psc)    destroy_psc ;;
    prerun) destroy_prerun ;;
    all)
      destroy_lb
      destroy_mig
      destroy_psc
      destroy_prerun
      ;;
    *) usage ;;
  esac
  info "Destroy Complete!"
fi