variable "project_id" {
  description = "Project ID."
  type        = string
}

variable "region" {
  type    = string
  default = "europe-west2"
}

variable "vpc_name" {
  description = "Project ID."
  type        = string
  default     = "apigee-sme"
}

variable "vpc_subnets" {
  description = "Subnets for exposing Apigee services"
  type        = string
  default     = "apigee-exposure-1"
}

variable "psc_subnets" {
  description = "Subnets for psc endpoints"
  type        = string
  default     = "psc-subnet-1"
}

variable "swp_allowlist_hosts" {
  type    = list(string)
  default = []
}