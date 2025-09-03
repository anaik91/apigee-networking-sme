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

output "mig_info" {
  value = local.mig_info
}

output "template_info" {
  value = local.template_info
}
