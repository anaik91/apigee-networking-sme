data "google_compute_network" "vpc" {
  project = var.project_id
  name    = var.vpc_name
}

data "google_compute_subnetwork" "subnetwork" {
  project = var.project_id
  name    = var.vpc_subnets
  region  = var.region
}

resource "google_compute_subnetwork" "psc" {
  project       = var.project_id
  name          = "psc-subnetwork"
  ip_cidr_range = "10.2.0.0/16"
  region        = var.region
  network       = data.google_compute_network.vpc.id
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

module "addresses" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-address?ref=v42.0.0"
  project_id = var.project_id
  internal_addresses = {
    gateway = {
      region     = var.region
      subnetwork = data.google_compute_subnetwork.subnetwork.id
    }
  }
  global_addresses = {
    apigee = {}
  }
}

module "swp" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-swp?ref=v42.0.0"
  project_id = var.project_id
  region     = var.region
  name       = "gateway"
  network    = data.google_compute_network.vpc.id
  subnetwork = data.google_compute_subnetwork.subnetwork.id
  gateway_config = {
    addresses = [module.addresses.internal_addresses["gateway"].address]
    ports     = [8080]
  }
  service_attachment = {
    nat_subnets          = [google_compute_subnetwork.psc.id]
    automatic_connection = true
  }
}

resource "google_apigee_endpoint_attachment" "swp" {
  location               = var.region
  service_attachment     = module.swp.service_attachment
  org_id                 = "organizations/${var.project_id}"
  endpoint_attachment_id = "swp"
}
