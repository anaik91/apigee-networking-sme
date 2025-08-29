output "psc_endpoint_address" {
  value = { for key, value in google_compute_address.psc_endpoint_address :
    value.region => value.address
  }
}