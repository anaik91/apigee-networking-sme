# 0. Pre-Run: Apigee X Core

This directory contains the foundational Terraform configuration for the entire environment. It provisions the core Apigee X instance and its immediate dependencies.

## Architecture

This stage provisions the following resources:
- An Apigee X instance.
- The necessary VPC network and subnets for Apigee.
- A sample API proxy (`mock`) for testing connectivity after deployment.

## Usage

It is highly recommended to use the `run.sh` script in the root directory to apply these configurations.

To apply the pre-run stage:
```sh
./run.sh --project YOUR_PROJECT_ID --apply prerun
```

Refer to the main [README.md](../README.md) for more details on the execution flow and prerequisites.
