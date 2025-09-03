# 2. Southbound Traffic Management

This directory contains the Terraform configurations for managing southbound traffic, which is the traffic flowing from the Apigee X instance to backend services.

The resources are provisioned in a specific order to ensure dependencies are met. The `run.sh` script in the root of this repository automates this process.

## Stages

### `0_swp`
Deploys a Secure Web Proxy instance. This can be used to control egress traffic from Apigee, providing a secure and managed way for Apigee to connect to external services.

### `1_backend`
Deploys a sample Nginx backend service. This serves as a target for API proxies deployed in Apigee, allowing you to test the end-to-end traffic flow.

## Usage

It is highly recommended to use the `run.sh` script in the root directory to apply these configurations.

To apply all southbound stages:
```sh
./run.sh --project YOUR_PROJECT_ID --apply all
```

To apply a specific southbound stage:
```sh
./run.sh --project YOUR_PROJECT_ID --apply [swp|backend]
```

Refer to the main [README.md](../README.md) for more details on the execution flow and prerequisites.
