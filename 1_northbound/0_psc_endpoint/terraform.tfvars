/**
 * Copyright 2023 Google LLC
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


vpc_name = "apigee-sme"

exposure_subnets = [
  {
    name               = "apigee-exposure-1"
    ip_cidr_range      = "10.100.0.0/24"
    region             = "europe-west2"
    instance           = "euw1-instance"
    secondary_ip_range = null
  },

]

psc_subnets = [
  {
    name               = "psc-subnet-1"
    ip_cidr_range      = "10.100.255.240/28"
    region             = "europe-west2"
    instance           = "euw1-instance"
    secondary_ip_range = null
  }
]