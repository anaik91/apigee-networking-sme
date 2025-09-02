output "psc_endpoint_address" {
  value = { for key, value in google_compute_address.psc_endpoint_address :
    value.region => {
      address : value.address
      network : module.vpc.self_link
      subnetwork : value.subnetwork
    }
  }
}