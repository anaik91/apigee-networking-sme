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
  api_deploy_env    = keys(var.apigee_environments)[0]
  fwd_proxy_enabled = length(var.forward_proxy_url) > 0
  
  environments = {
    for k, v in var.apigee_environments : k => merge(
      v,
      local.fwd_proxy_enabled ? { forward_proxy_uri = var.forward_proxy_url } : {}
    )
  }
  envgroups = { for key, value in var.apigee_envgroups : key => value.hostnames }
  instances = { for key, value in var.apigee_instances : value.region => {
      name                  = key
      environments          = value.environments
    }
  }
}

module "project" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/project?ref=v42.0.0"
  name          = var.project_id
  project_reuse = { use_data_source = true }
  services = [
    "apigee.googleapis.com",
    "compute.googleapis.com",
    "networksecurity.googleapis.com",
    "networkservices.googleapis.com"
  ]
}

module "apigee" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/apigee?ref=v42.0.0"
  project_id = module.project.id
  organization = {
    runtime_type        = "CLOUD"
    analytics_region    = var.ax_region
    disable_vpc_peering = true
  }
  envgroups    = local.envgroups
  environments = local.environments
  instances    = local.instances
}

data "archive_file" "api_proxy" {
  type             = "zip"
  source_dir       = "${path.module}/api_proxy"
  output_path      = "${path.module}/${var.mock_api_proxy_name}.zip"
  output_file_mode = "0644"
}

resource "google_apigee_api" "api_proxy" {
  name          = var.mock_api_proxy_name
  org_id        = module.apigee.organization.name
  config_bundle = data.archive_file.api_proxy.output_path
}

data "google_client_config" "default" {
}

resource "local_file" "deploy_apiproxy_file" {
  content = templatefile("${path.module}/deploy-apiproxy.sh.tpl", {
    organization = module.apigee.organization.name
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