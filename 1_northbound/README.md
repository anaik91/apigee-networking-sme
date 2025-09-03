# 1. Northbound Traffic Management

This directory contains the Terraform configurations for managing northbound traffic, which is the traffic flowing from external clients to the Apigee X instance.

The resources are provisioned in a specific order to ensure dependencies are met. The `run.sh` script in the root of this repository automates this process.

## Stages

### `0_psc_endpoint`
Creates a Private Service Connect (PSC) endpoint to connect to the Apigee instance's service attachment. This allows resources in your VPC to privately and securely connect to Apigee.

### `1_mig`
Creates a Managed Instance Group (MIG) of proxy VMs. These VMs will receive traffic from the external load balancer and forward it to the PSC endpoint, effectively bridging the external network with the internal Apigee instance.

### `2_load_balancer`
Creates a Global External HTTPS Load Balancer to expose the MIG to the internet. This provides a single, stable IP address for external clients to send their API requests to.

## Usage

It is highly recommended to use the `run.sh` script in the root directory to apply these configurations.

To apply all northbound stages:
```sh
./run.sh --project YOUR_PROJECT_ID --apply all
```

To apply a specific northbound stage:
```sh
./run.sh --project YOUR_PROJECT_ID --apply [psc|mig|ilb]
```

Refer to the main [README.md](../README.md) for more details on the execution flow and prerequisites.
