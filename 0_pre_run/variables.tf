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
  description = "Project id (also used for the Apigee Organization)."
  type        = string
}

variable "ax_region" {
  description = "GCP region for storing Apigee analytics data (see https://cloud.google.com/apigee/docs/api-platform/get-started/install-cli)."
  type        = string
  default     = "europe-west2"
}

variable "apigee_instances" {
  description = "Apigee Instances (only one instance for EVAL orgs)."
  type = map(object({
    region       = string
    environments = list(string)
  }))
  default = {
    euw2-instance = {
      region       = "europe-west2"
      environments = ["test1", "test2"]
    }
  }
}

variable "apigee_envgroups" {
  description = "Apigee Environment Groups."
  type = map(object({
    hostnames = list(string)
  }))
  default = {
    test = {
      hostnames = ["test.api.example.com"]
    }
  }
}

variable "apigee_environments" {
  description = "Apigee Environments."
  type = map(object({
    display_name = optional(string)
    description  = optional(string)
    node_config = optional(object({
      min_node_count = optional(number)
      max_node_count = optional(number)
    }))
    iam       = optional(map(list(string)))
    envgroups = list(string)
    type      = optional(string)
  }))
  default = {
    test1 = {
      display_name = "Test 1"
      description  = "Environment created by apigee/terraform-modules"
      node_config  = null
      iam          = null
      envgroups    = ["test"]
      type         = null
    }
    test2 = {
      display_name = "Test 2"
      description  = "Environment created by apigee/terraform-modules"
      node_config  = null
      iam          = null
      envgroups    = ["test"]
      type         = null
    }
  }
}

variable "mock_api_proxy_name" {
  description = "Name of API proxy to be created"
  default     = "mock"
}

variable "forward_proxy_url" {
  type    = string
  default = ""
}