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
  backend_config = [
    for key, value in var.instance_group : {
      group = value.instance_group
    }
  ]

  mig_info = {
    for key, value in var.instance_group :
    key => data.google_compute_region_instance_group_manager.migs[key]
  }

  template_info = {
    for key, value in var.instance_group :
    key => data.google_compute_region_instance_template.migs[key]
  }
}

data "google_compute_region_instance_group_manager" "migs" {
  for_each = var.instance_group
  project  = var.project_id
  region   = split("/", each.value.instance_group)[8]
  name     = split("/", each.value.instance_group)[10]
}

data "google_compute_region_instance_template" "migs" {
  for_each = local.mig_info
  project  = var.project_id
  name     = split("/", each.value.version[0].instance_template)[10]
  region   = split("/", each.value.version[0].instance_template)[8]
}

resource "tls_private_key" "default" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "default" {
  private_key_pem = tls_private_key.default.private_key_pem
  subject {
    common_name  = "test.api.example.com"
    organization = "SME Academy, Inc"
  }
  validity_period_hours = 720
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "google_compute_subnetwork" "proxy_subnet" {
  for_each      = local.template_info
  project       = var.project_id
  name          = "l7-gilb-proxy-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = each.key
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
  network       = each.value.network_interface[0].network
}

module "ilb-l7" {
  for_each   = local.template_info
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-app-int?ref=v42.0.0"
  name       = "ilb-test"
  project_id = var.project_id
  region     = each.key
  backend_service_configs = {
    default = {
      port_name = "https"
      backends = local.backend_config
      port_name = "https"
    }
  }
  health_check_configs = {
    default = {
      https = { port = 443, request_path = "/healthz/ingress" }
    }
  }
  protocol = "HTTPS"
  ssl_certificates = {
    create_configs = {
      default = {
        # certificate and key could also be read via file() from external files
        certificate = tls_self_signed_cert.default.cert_pem
        private_key = tls_private_key.default.private_key_pem
      }
    }
  }
  vpc_config = {
    network    = each.value.network_interface[0].network
    subnetwork = each.value.network_interface[0].subnetwork
  }

  depends_on = [google_compute_subnetwork.proxy_subnet]
}