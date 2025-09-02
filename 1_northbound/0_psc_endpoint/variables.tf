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

variable "project_id" {
  description = "Project ID."
  type        = string
}

variable "vpc_name" {
  description = "Project ID."
  type        = string
  default     = "apigee-sme"
}

variable "exposure_subnets" {
  description = "Subnets for exposing Apigee services"
  type = list(object({
    name               = string
    ip_cidr_range      = string
    region             = string
    instance           = string
    secondary_ip_range = map(string)
  }))
  default = [
    {
      name               = "apigee-exposure-1"
      ip_cidr_range      = "10.100.0.0/24"
      region             = "europe-west4"
      instance           = "euw1-instance"
      secondary_ip_range = null
    },

  ]
}

variable "psc_subnets" {
  description = "Subnets for psc endpoints"
  type = list(object({
    name               = string
    ip_cidr_range      = string
    region             = string
    instance           = string
    secondary_ip_range = map(string)
  }))
  default = [
    {
      name               = "psc-subnet-1"
      ip_cidr_range      = "10.100.255.240/29"
      region             = "europe-west4"
      instance           = "euw1-instance"
      secondary_ip_range = null
    }
  ]
}

variable "apigee_service_attachments" {
  description = "Map of instance region -> instance PSC service attachment"
  type        = map(string)
}