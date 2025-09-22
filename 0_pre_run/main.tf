/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  services = [
    "apigee.googleapis.com",
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "networksecurity.googleapis.com",
    "networkservices.googleapis.com",
    "iam.googleapis.com"
  ]
  api_deploy_env    = keys(var.apigee_environments)[0]
  fwd_proxy_enabled = length(var.forward_proxy_url) > 0
  environments = {
    for k, v in var.apigee_environments : k => merge(
      v,
      local.fwd_proxy_enabled ? { forward_proxy_uri = var.forward_proxy_url } : {}
    )
  }
}

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_project_service" "project" {
  for_each           = toset(local.services)
  project            = data.google_project.project.id
  service            = each.key
  disable_on_destroy = false
}

resource "google_project_service_identity" "apigee_sa" {
  provider = google-beta
  project  = data.google_project.project.project_id
  service  = "apigee.googleapis.com"
}

module "apigee-x-core" {
  source              = "../modules/apigee-x-core"
  project_id          = data.google_project.project.project_id
  apigee_environments = local.environments
  ax_region           = var.ax_region
  apigee_envgroups = {
    for name, env_group in var.apigee_envgroups : name => {
      hostnames = env_group.hostnames
    }
  }
  apigee_instances    = var.apigee_instances
  disable_vpc_peering = true
}

data "archive_file" "api_proxy" {
  type             = "zip"
  source_dir       = "${path.module}/api_proxy"
  output_path      = "${path.module}/${var.mock_api_proxy_name}.zip"
  output_file_mode = "0644"
}

resource "google_apigee_api" "api_proxy" {
  name          = var.mock_api_proxy_name
  org_id        = module.apigee-x-core.organization.name
  config_bundle = data.archive_file.api_proxy.output_path
}

data "google_client_config" "default" {
}

resource "local_file" "deploy_apiproxy_file" {
  content = templatefile("${path.module}/deploy-apiproxy.sh.tpl", {
    organization = module.apigee-x-core.organization.name
    environment  = local.api_deploy_env
    api_name     = var.mock_api_proxy_name
  })
  filename        = "${path.module}/deploy-apiproxy.sh"
  file_permission = "0755"
}

resource "null_resource" "deploy_api" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/deploy-apiproxy.sh"
  }

  depends_on = [google_apigee_api.api_proxy, local_file.deploy_apiproxy_file]
}

output "apigee_environments" {
  value = local.environments
}