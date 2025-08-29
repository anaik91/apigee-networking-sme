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
  psc_subnets = { for psc in var.psc_subnets :
    psc.name => psc
  }
}

data "google_project" "project" {
  project_id = var.project_id
}


module "vpc" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc?ref=v42.0.0"
  project_id = data.google_project.project.id
  name       = var.vpc_name
  subnets = [
    for subnet in var.psc_subnets :
    {
      "name"                = subnet.name
      "region"              = subnet.region
      "secondary_ip_ranges" = subnet.secondary_ip_range
      "ip_cidr_range"       = subnet.ip_cidr_range
    }
  ]
}

resource "google_compute_address" "psc_endpoint_address" {
  for_each     = local.psc_subnets
  name         = "psc-ip-${each.value.region}"
  project      = data.google_project.project.id
  address_type = "INTERNAL"
  subnetwork   = module.vpc.subnet_self_links["${each.value.region}/${each.value.name}"]
  region       = each.value.region
}

resource "google_compute_forwarding_rule" "psc_ilb_consumer" {
  for_each              = local.psc_subnets
  name                  = "psc-ea-${each.value.region}"
  project               = data.google_project.project.id
  region                = each.value.region
  target                = var.apigee_service_attachments[each.value.region]
  load_balancing_scheme = ""
  network               = module.vpc.network.id
  ip_address            = google_compute_address.psc_endpoint_address[each.value.name].id
  depends_on = [
    google_compute_address.psc_endpoint_address,
  ]
}
