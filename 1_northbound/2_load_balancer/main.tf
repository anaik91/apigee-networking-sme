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
  hostname = "${replace(google_compute_global_address.external_address.address, ".", "-")}.nip.io"
  domains  = [local.hostname]
}

resource "google_compute_global_address" "external_address" {
  name         = "lb-${var.lb_name}-ip"
  project      = var.project_id
  address_type = "EXTERNAL"
}

data "google_compute_global_address" "my_lb_external_address" {
  name    = google_compute_global_address.external_address.name
  project = var.project_id
}

resource "google_compute_managed_ssl_certificate" "google_cert" {
  project = var.project_id
  name    = "ssl-cert"
  managed {
    domains = local.domains
  }
}

module "mig-l7xlb" {
  source          = "../../modules/mig-l7xlb"
  project_id      = var.project_id
  name            = var.lb_name
  backend_migs    = [var.instance_group]
  ssl_certificate = [google_compute_managed_ssl_certificate.google_cert.id]
  external_ip     = data.google_compute_global_address.my_lb_external_address.address
}