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
  echo "Usage: $0 --project <PROJECT_ID> --[apply|destroy|client] <stage>"
  echo " "
  echo "Arguments:"
  echo "  --project <PROJECT_ID>    : Your Google Cloud Project ID (Required)."
  echo "  --client <stage>          : Client access stages."
  echo "  --apply <stage>           : Apply the specified stage."
  echo "  --destroy <stage>         : Destroy the specified stage."
  echo " "
  echo "Stages for client: [access, access_test_psc, access_test_mig, access_test_lb]"
  echo "Stages for apply: [prerun, psc, mig, ilb, swp, backend, set_fwd_proxy, allowlist_mock, allowlist_nginx, deploy_backend_proxy, all]"
  echo "Stages for destroy: [prerun, psc, mig, ilb, swp, backend, all]"
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

gcloud_ssh() {
  check_dependency "1_northbound/0_psc_endpoint" "PSC Endpoint" "psc"
  info "Stage 0: SSH ing into the client VM"
  (
    gcloud compute ssh --zone "europe-west2-b" "apigee-client-vm" --tunnel-through-iap --project "$PROJECT_ID"
  )
}

gcloud_ssh_curl_psc() {
  check_dependency "1_northbound/0_psc_endpoint" "PSC Endpoint" "psc"

  local psc_endpoint_address
  psc_endpoint_address=$(cd 1_northbound/0_psc_endpoint && terraform output -json | jq -r '.psc_endpoint_address.value."europe-west2".address')

  info "Stage 0: SSH ing into the client VM and sending a curl request to PSC IP: $psc_endpoint_address"
  ( 
    gcloud compute ssh --zone "europe-west2-b" "apigee-client-vm" --tunnel-through-iap --project "$PROJECT_ID" -- \
    curl --connect-to "test.api.example.com:443:${psc_endpoint_address}" https://test.api.example.com/mock -k -v
  )
}

gcloud_ssh_curl_mig() {
  check_dependency "1_northbound/1_mig" "MIG" "mig"
  mig_name=$(cd 1_northbound/1_mig && terraform output -json | jq -r '.instance_group.value."europe-west2".instance_group' | xargs -I {} basename {})
  local instance_names
  instance_names=$(gcloud compute instance-groups managed list-instances "$mig_name" \
    --project="$PROJECT_ID" \
    --region="europe-west2" \
    --format="value(instance.basename())")
  
  # Exit if no instances are found in the MIG
  if [ -z "$instance_names" ]; then
    echo "🟡 No instances found in MIG '$mig_name' in project '$PROJECT_ID'."
    return 0
  fi

  local instance_filter
  instance_filter=$(echo "$instance_names" | tr '\n' ' ')

  echo "✅ Private IPs for instances in MIG '$mig_name':"
  for ip in $(gcloud compute instances list \
    --project="$PROJECT_ID" \
    --filter="name:($instance_filter)" \
    --format="value(networkInterfaces[0].networkIP)")
  do 
    info "Stage 0: SSH ing into the client VM and sending a curl request to IP: $ip"
    (
      gcloud compute ssh --zone "europe-west2-b" "apigee-client-vm" --tunnel-through-iap --project "$PROJECT_ID" -- \
      curl --connect-to "test.api.example.com:443:$ip" https://test.api.example.com/mock -k -v
    )
  done
}

gcloud_ssh_curl_lb() {
  check_dependency "1_northbound/2_load_balancer" "LoadBalancer" "lb"

  local lb_address
  lb_address=$(cd 1_northbound/2_load_balancer && terraform output -json | jq -r '.address.value.[0]')

  info "Stage 0: SSH ing into the client VM and sending a curl request to IP: $lb_address"
  (
    gcloud compute ssh --zone "europe-west2-b" "apigee-client-vm" --tunnel-through-iap --project "$PROJECT_ID" -- \
    curl --connect-to "test.api.example.com:443:$lb_address" https://test.api.example.com/mock -k -v
  )
}

deploy_prerun() {
  info "Stage 0: Deploying Pre-run (Apigee Core)"
  ( # Run in a subshell to avoid changing the script's directory
    cd 0_pre_run
    terraform init
    TF_VAR_project_id=$PROJECT_ID terraform apply -auto-approve
    bash deploy-apiproxy.sh
  )
}

deploy_set_fwd_proxy() {
  local fwd_proxy_url
  fwd_proxy_url=$(cd 2_southbound/0_swp && terraform output -json | jq -r .forward_proxy_url.value)

  info "Stage 2: Set Forward Proxy as $fwd_proxy_url"
  ( # Run in a subshell to avoid changing the script's directory
    cd 0_pre_run
    terraform init
    TF_VAR_project_id=$PROJECT_ID TF_VAR_forward_proxy_url=$fwd_proxy_url terraform apply -auto-approve
  )
}

deploy_psc() {
  check_dependency "0_pre_run" "Pre-run" "prerun"
  info "Stage 1.0: Deploying Northbound PSC Endpoint"
  
  # Read output directly from the dependency's state
  local apigee_sa
  apigee_sa=$(cd 0_pre_run && terraform output -json | jq -c .apigee_service_attachments.value)

  (
    cd 1_northbound/0_psc_endpoint
    terraform init
    # Pass the output from the previous step as a TF_VAR for this command
    TF_VAR_apigee_service_attachments=$apigee_sa TF_VAR_project_id=$PROJECT_ID terraform apply -auto-approve
  )
}

deploy_mig() {
  check_dependency "1_northbound/0_psc_endpoint" "PSC Endpoint" "psc"
  info "Stage 1.1: Deploying Northbound MIG"

  local psc_endpoint_address
  psc_endpoint_address=$(cd 1_northbound/0_psc_endpoint && terraform output -json | jq -c .psc_endpoint_address.value)
  (
    cd 1_northbound/1_mig
    terraform init
    TF_VAR_psc_endpoint_address=$psc_endpoint_address TF_VAR_project_id=$PROJECT_ID terraform apply -auto-approve
  )
}

deploy_ilb() {
  check_dependency "1_northbound/1_mig" "MIG" "mig"
  info "Stage 1.2: Deploying Northbound Load Balancer"

  local instance_group
  instance_group=$(cd 1_northbound/1_mig && terraform output -json | jq -c .instance_group.value)
  
  (
    cd 1_northbound/2_load_balancer
    terraform init
    TF_VAR_instance_group=$instance_group TF_VAR_project_id=$PROJECT_ID terraform apply -auto-approve
  )
}

deploy_swp() {
  check_dependency "1_northbound/2_load_balancer" "LoadBalancer" "lb"
  info "Stage 2.1: Deploying Secure Web Proxy"
  (
    cd 2_southbound/0_swp
    terraform init
    TF_VAR_project_id=$PROJECT_ID terraform apply -auto-approve
  )
}

deploy_backend() {
  check_dependency "2_southbound/0_swp" "SWP" "swp"
  info "Stage 2.2: Deploying Sample Nginx Backend"
  (
    cd 2_southbound/1_backend
    terraform init
    TF_VAR_project_id=$PROJECT_ID terraform apply -auto-approve
  )
}

allowlist_mock() {
  check_dependency "2_southbound/0_swp" "SWP" "swp"
  info "Stage : Allowlisting mocktarget.apigee.net"
  (
    cd 2_southbound/0_swp
    terraform init
    TF_VAR_project_id=$PROJECT_ID TF_VAR_swp_allowlist_hosts="[\"mocktarget.apigee.net\"]" terraform apply -auto-approve
  )
}

allowlist_nginx() {
  check_dependency "2_southbound/0_swp" "SWP" "swp"

  local nginx_ip
  nginx_ip=$(cd 2_southbound/1_backend && terraform output -json | jq -r .backend_ip.value)
  info "Stage : Allowlisting Nginx IP: ${nginx_ip}"
  (
    cd 2_southbound/0_swp
    terraform init
    TF_VAR_project_id=$PROJECT_ID TF_VAR_swp_allowlist_hosts="[\"mocktarget.apigee.net\",\"$nginx_ip\"]" terraform apply -auto-approve
  )
}

deploy_backend_proxy() {
  check_dependency "2_southbound/1_backend" "Nginx " "backend"
  local nginx_ip
  nginx_ip=$(cd 2_southbound/1_backend && terraform output -json | jq -r .backend_ip.value)
  info "Stage 2.3: Deploying Nginx Backend API Proxy with IP : $nginx_ip"
  (
    cd 2_southbound/2_apiproxy
    terraform init
    TF_VAR_project_id=$PROJECT_ID TF_VAR_nginx_ip=$nginx_ip terraform apply -auto-approve
    bash deploy-apiproxy.sh
  )
}


# --- Destroy Functions (in REVERSE order of execution) ---

destroy_backend() {
  info "Destroying Sample Nginx Backend"
  (cd 2_southbound/1_backend && terraform destroy -auto-approve)
}

destroy_swp() {
  info "Destroying Secure Web Proxy"
  (cd 2_southbound/0_swp && terraform destroy -auto-approve)
}

destroy_ilb() {
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
    --client) ACTION="client"; STAGE="$2"; shift; shift;;
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
# Execute the requested action and stage
if [ "$ACTION" == "client" ]; then
  case $STAGE in
    access) gcloud_ssh ;;
    access_test_psc)    gcloud_ssh_curl_psc ;;
    access_test_mig)    gcloud_ssh_curl_mig ;;
    access_test_lb)    gcloud_ssh_curl_lb ;;
    *) usage ;;
  esac
  info "Client Action Complete!"

elif [ "$ACTION" == "apply" ]; then
  case $STAGE in
    prerun) deploy_prerun ;;
    psc)    deploy_psc ;;
    mig)    deploy_mig ;;
    ilb)     deploy_ilb ;;
    swp)     deploy_swp ;;
    backend)     deploy_backend ;;
    set_fwd_proxy) deploy_set_fwd_proxy ;;
    allowlist_mock) allowlist_mock ;;
    allowlist_nginx) allowlist_nginx ;;
    deploy_backend_proxy) deploy_backend_proxy;;
    all)
      deploy_prerun
      deploy_psc
      deploy_mig
      deploy_ilb
      deploy_swp
      deploy_backend
      deploy_set_fwd_proxy
      ;;
    *) usage ;;
  esac
  info "Apply Complete!"

elif [ "$ACTION" == "destroy" ]; then
  case $STAGE in
    backend) destroy_backend ;;
    swp)     destroy_swp ;;
    ilb)     destroy_ilb ;;
    mig)    destroy_mig ;;
    psc)    destroy_psc ;;
    prerun) destroy_prerun ;;
    all)
      destroy_backend
      destroy_swp
      destroy_ilb
      destroy_mig
      destroy_psc
      destroy_prerun
      ;;
    *) usage ;;
  esac
  info "Destroy Complete!"
fi