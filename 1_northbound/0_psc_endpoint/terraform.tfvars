# Auto-generated from defaults.toml. Do not edit manually.

vpc_name = "apigee-sme"

exposure_subnets = [
  {
  name = "apigee-exposure-1"
  ip_cidr_range = "10.100.0.0/24"
  region = "europe-west2"
  instance = "euw1-instance"
  secondary_ip_range = null
}
]
psc_subnets = [
  {
  name = "psc-subnet-1"
  ip_cidr_range = "10.100.255.240/28"
  region = "europe-west2"
  instance = "euw1-instance"
  secondary_ip_range = null
}
]
