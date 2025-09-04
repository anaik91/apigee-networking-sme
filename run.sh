#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Script Configuration ---
PROJECT_ID=""
ACTION=""
STAGE=""

# --- Global Configuration ---
GCP_ZONE="europe-west2-b"
GCP_REGION="europe-west2"
CLIENT_VM_NAME="apigee-client-vm"
TEST_HOSTNAME="test.api.example.com"

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

  if [ ! -f "${stage_dir}/terraform.tfstate" ] || [ ! -s "${stage_dir}/terraform.tfstate" ]; then
    echo " "
    echo "ERROR: Prerequisite stage '${stage_name}' has not been successfully applied." >&2
    echo "The state file at '${stage_dir}/terraform.tfstate' is missing or empty." >&2
    echo "Please run './run.sh --project ${PROJECT_ID} --apply ${stage_flag}' first." >&2
    exit 1
  fi
}

# --- Reusable Terraform & Cloud Functions ---

run_terraform() {
  local action="$1"
  local dir="$2"
  shift 2
  
  info "Terraform $action in $dir"
  (
    cd "$dir"
    terraform init -upgrade > /dev/null
    # Pass remaining arguments to terraform
    terraform "$action" -auto-approve "$@"
  )
}

get_tf_output() {
  local dir="$1"
  local output_name="$2"
  (cd "$dir" && terraform output -json "$output_name" | jq -c .)
}

run_ssh_curl() {
  local ip_address="$1"
  local hostname="$2"
  info "SSH into client VM and curl $hostname via IP: $ip_address"
  gcloud compute ssh --zone "$GCP_ZONE" "$CLIENT_VM_NAME" --tunnel-through-iap --project "$PROJECT_ID" -- \
    "curl --connect-to \"$hostname:443:$ip_address\" https://$hostname/mock -k -v"
}

# --- Deployment Functions ---

deploy_prerun() {
  info "Stage 0: Deploying Pre-run (Apigee Core)"
  run_terraform "apply" "0_pre_run"
  (cd 0_pre_run && bash deploy-apiproxy.sh)
}

deploy_psc() {
  check_dependency "0_pre_run" "Pre-run" "prerun"
  info "Stage 1.0: Deploying Northbound PSC Endpoint"
  local apigee_sa
  apigee_sa=$(get_tf_output "0_pre_run" "apigee_service_attachments")
  run_terraform "apply" "1_northbound/0_psc_endpoint" -var="apigee_service_attachments=$apigee_sa"
}

deploy_mig() {
  check_dependency "1_northbound/0_psc_endpoint" "PSC Endpoint" "psc"
  info "Stage 1.1: Deploying Northbound MIG"
  local psc_addr
  psc_addr=$(get_tf_output "1_northbound/0_psc_endpoint" "psc_endpoint_address")
  run_terraform "apply" "1_northbound/1_mig" -var="psc_endpoint_address=$psc_addr"
}

deploy_ilb() {
  check_dependency "1_northbound/1_mig" "MIG" "mig"
  info "Stage 1.2: Deploying Northbound Load Balancer"
  local instance_group
  instance_group=$(get_tf_output "1_northbound/1_mig" "instance_group")
  run_terraform "apply" "1_northbound/2_load_balancer" -var="instance_group=$instance_group"
}

deploy_swp() {
  check_dependency "1_northbound/2_load_balancer" "LoadBalancer" "ilb"
  info "Stage 2.1: Deploying Secure Web Proxy"
  run_terraform "apply" "2_southbound/0_swp"
}

deploy_backend() {
  check_dependency "2_southbound/0_swp" "SWP" "swp"
  info "Stage 2.2: Deploying Sample Nginx Backend"
  run_terraform "apply" "2_southbound/1_backend"
}

deploy_set_fwd_proxy() {
  check_dependency "2_southbound/0_swp" "SWP" "swp"
  local fwd_proxy_url
  fwd_proxy_url=$(get_tf_output "2_southbound/0_swp" "forward_proxy_url" | jq -r .)
  info "Stage 2: Set Forward Proxy to $fwd_proxy_url"
  run_terraform "apply" "0_pre_run" -var="forward_proxy_url=$fwd_proxy_url"
}

update_swp_allowlist() {
  check_dependency "2_southbound/0_swp" "SWP" "swp"
  local hosts_json="$1"
  info "Stage: Updating SWP allowlist with hosts: $hosts_json"
  run_terraform "apply" "2_southbound/0_swp" -var="swp_allowlist_hosts=$hosts_json"
}

deploy_backend_proxy() {
  check_dependency "2_southbound/1_backend" "Nginx" "backend"
  local nginx_ip
  nginx_ip=$(get_tf_output "2_southbound/1_backend" "backend_ip" | jq -r .)
  info "Stage 2.3: Deploying Nginx Backend API Proxy with IP: $nginx_ip"
  run_terraform "apply" "2_southbound/2_apiproxy" -var="nginx_ip=$nginx_ip"
  (cd 2_southbound/2_apiproxy && bash deploy-apiproxy.sh)
}

# --- Client Access Functions ---

gcloud_ssh() {
  check_dependency "1_northbound/0_psc_endpoint" "PSC Endpoint" "psc"
  info "SSH into the client VM"
  gcloud compute ssh --zone "$GCP_ZONE" "$CLIENT_VM_NAME" --tunnel-through-iap --project "$PROJECT_ID"
}

gcloud_ssh_curl_psc() {
  check_dependency "1_northbound/0_psc_endpoint" "PSC Endpoint" "psc"
  local psc_ip
  psc_ip=$(get_tf_output "1_northbound/0_psc_endpoint" "psc_endpoint_address" | jq -r ".\"$GCP_REGION\".address")
  run_ssh_curl "$psc_ip" "$TEST_HOSTNAME"
}

gcloud_ssh_curl_mig() {
  check_dependency "1_northbound/1_mig" "MIG" "mig"
  local mig_name
  mig_name=$(get_tf_output "1_northbound/1_mig" "instance_group" | jq -r ".\"$GCP_REGION\".instance_group" | xargs -I {} basename {})
  
  local instance_ips
  instance_ips=$(gcloud compute instances list \
    --project="$PROJECT_ID" \
    --filter="name~^$mig_name" \
    --format="value(networkInterfaces[0].networkIP)")

  if [ -z "$instance_ips" ]; then
    echo "🟡 No instances found in MIG '$mig_name'."
    return 0
  fi

  for ip in $instance_ips; do
    run_ssh_curl "$ip" "$TEST_HOSTNAME"
  done
}

gcloud_ssh_curl_lb() {
  check_dependency "1_northbound/2_load_balancer" "LoadBalancer" "ilb"
  local lb_ip
  lb_ip=$(get_tf_output "1_northbound/2_load_balancer" "address" | jq -r ".[0]")
  run_ssh_curl "$lb_ip" "$TEST_HOSTNAME"
}

# --- Main Execution Logic ---

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

if [ -z "$PROJECT_ID" ] || [ -z "$ACTION" ] || [ -z "$STAGE" ]; then
  echo "Error: Missing required arguments." >&2
  usage
fi

export TF_VAR_project_id=$PROJECT_ID
info "Using Project ID: $PROJECT_ID"

case $ACTION in
  client)
    case $STAGE in
      access) gcloud_ssh ;;
      access_test_psc) gcloud_ssh_curl_psc ;;
      access_test_mig) gcloud_ssh_curl_mig ;;
      access_test_lb) gcloud_ssh_curl_lb ;;
      *) usage ;;
    esac
    info "Client Action Complete!"
    ;;
  apply)
    case $STAGE in
      prerun) deploy_prerun ;;
      psc) deploy_psc ;;
      mig) deploy_mig ;;
      ilb) deploy_ilb ;;
      swp) deploy_swp ;;
      backend) deploy_backend ;;
      set_fwd_proxy) deploy_set_fwd_proxy ;;
      allowlist_mock) update_swp_allowlist '["mocktarget.apigee.net"]' ;;
      allowlist_nginx)
        nginx_ip=$(get_tf_output "2_southbound/1_backend" "backend_ip" | jq -r .)
        update_swp_allowlist "[\"mocktarget.apigee.net\",\"$nginx_ip\"]"
        ;;
      deploy_backend_proxy) deploy_backend_proxy ;;
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
    ;;
  destroy)
    # Define destroy stages in reverse order of application
    destroy_stages=(backend swp ilb mig psc prerun)
    dirs=(2_southbound/1_backend 2_southbound/0_swp 1_northbound/2_load_balancer 1_northbound/1_mig 1_northbound/0_psc_endpoint 0_pre_run)
    
    found=false
    for i in "${!destroy_stages[@]}"; do
      if [ "$STAGE" == "all" ] || [ "$STAGE" == "${destroy_stages[$i]}" ]; then
        found=true
      fi
      if [ "$found" == "true" ]; then
        run_terraform "destroy" "${dirs[$i]}"
      fi
    done
    if [ "$found" == "false" ]; then
      usage
    fi
    info "Destroy Complete!"
    ;;
esac