data "google_compute_network" "vpc" {
  project = var.project_id
  name    = var.vpc_name
}

data "google_compute_subnetwork" "subnetwork" {
  project = var.project_id
  name    = var.vpc_subnets
  region  = var.region
}

module "nat" {
  source         = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v42.0.0"
  project_id     = var.project_id
  region         = var.region
  name           = "default"
  router_network = data.google_compute_network.vpc.self_link
  config_source_subnetworks = {
    all = false
    subnetworks = [
      {
        # all ip ranges
        self_link = data.google_compute_subnetwork.subnetwork.self_link
      }
    ]
  }
}
# tftest modules=1 resources=2

module "nginx_vm" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/compute-vm?ref=v42.0.0"
  project_id = var.project_id
  zone       = "${var.region}-b"
  name       = "nginx"
  network_interfaces = [{
    network    = data.google_compute_network.vpc.id
    subnetwork = data.google_compute_subnetwork.subnetwork.id
  }]
  metadata = {
    startup-script = <<-EOF
      #! /bin/bash
      apt-get update
      apt-get install -y nginx
    EOF
  }
  service_account = {
    auto_create = true
  }
  tags = [
    "http-server", "ssh"
  ]
  depends_on = [module.nat]
}