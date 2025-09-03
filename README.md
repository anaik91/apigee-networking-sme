# Apigee Networking SME - Terraform Scenario Based Session

This repository contains Terraform code to demonstrate common networking patterns for Google Cloud Apigee X. The configurations are structured sequentially to build up a complete environment, from the core Apigee instance to northbound and southbound traffic management.

## Prerequisites

Before you begin, ensure you have the following installed and configured:
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) (v1.0 or later)
- [Google Cloud SDK (gcloud)](https://cloud.google.com/sdk/docs/install)
- An active Google Cloud project with billing enabled.
- Authenticated to gcloud with a user or service account having sufficient permissions (e.g., `roles/owner` or a combination of `roles/apigee.admin`, `roles/compute.admin`, `roles/iam.serviceAccountUser`).

## Execution Flow

The Terraform configurations are designed to be run in a specific order. Each numbered folder represents a distinct stage of the deployment. The included `run.sh` script automates this process, ensuring stages are applied or destroyed in the correct sequence.

```mermaid
graph TD
    U1[User Invoke run.sh] --> A
    subgraph "Terraform Execution Flow"
        A[0. Pre-Run: Apigee X Core] --> B[1. Northbound: External Access];
        B --> C[2. Southbound: Backend Connectivity];
    end
    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#ccf,stroke:#333,stroke-width:2px
    style C fill:#cfc,stroke:#333,stroke-width:2px
```

## Directory Structure

### `0_pre_run`
This directory lays the foundation for the environment. It uses the `apigee-x-core` module to provision:
- The core Apigee X instance.
- Required networking components (VPC, subnets).
- A sample API proxy for testing connectivity.

### `1_northbound`
This directory focuses on exposing the Apigee instance to external clients (northbound traffic). It is broken down into further sub-directories that must also be applied in order:
- **`0_psc_endpoint`**: Creates a Private Service Connect (PSC) endpoint to connect to the Apigee instance's service attachment.
- **`1_mig`**: Creates a Managed Instance Group (MIG) of proxy VMs that will forward traffic from the load balancer to the PSC endpoint.
- **`2_load_balancer`**: Creates a Global External HTTPS Load Balancer to expose the MIG to the internet.

### `2_southbound`
This directory is intended for configurations related to how Apigee connects to backend services (southbound traffic).
- **`0_swp`**: Deploys a Secure Web Proxy instance.
- **`1_backend`**: Deploys a sample Nginx backend.

### `modules`
This directory contains reusable Terraform modules that encapsulate best practices and reduce code duplication.
- **`apigee-x-core`**: A module for provisioning the core Apigee X instance and its immediate dependencies.
- **`mig`**: A module for creating the MIG for northbound traffic.

## How to Use

The `run.sh` script is the recommended way to apply and destroy the infrastructure.

1.  **Clone the repository:**
    ```sh
    git clone <repository_url>
    cd apigee-networking-sme
    ```

2.  **Run the script:**
    The script requires your Google Cloud Project ID and the desired action (`--apply`, `--destroy` or `--client`) and stage. The script will handle the correct order of execution and destruction automatically.

    **Example:**
    ```sh
    ./run.sh --project YOUR_PROJECT_ID --apply all
    ```

### Script Arguments and Stages

| Action      | Stage                  | Description                                                 |
| :---------- | :--------------------- | :---------------------------------------------------------- |
| **`--apply`**   | `prerun`               | Deploys the core Apigee X instance and network foundation.  |
|             | `psc`                  | Creates a Private Service Connect (PSC) endpoint.           |
|             | `mig`                  | Creates a Managed Instance Group (MIG) as a proxy layer.    |
|             | `ilb`                  | Deploys an Internal Load Balancer for the MIG.              |
|             | `swp`                  | Deploys a Secure Web Proxy for southbound traffic.          |
|             | `backend`              | Deploys a sample Nginx backend service.                     |
|             | `set_fwd_proxy`        | Configures Apigee to use the SWP as a forward proxy.        |
|             | `allowlist_mock`       | Adds `mocktarget.apigee.net` to the SWP allowlist.          |
|             | `allowlist_nginx`      | Adds the Nginx backend IP to the SWP allowlist.             |
|             | `deploy_backend_proxy` | Deploys an API proxy that connects to the Nginx backend.    |
|             | `all`                  | Applies all stages sequentially from `prerun` to `set_fwd_proxy`. |
| **`--destroy`** | `backend`              | Destroys the sample Nginx backend.                          |
|             | `swp`                  | Destroys the Secure Web Proxy.                              |
|             | `ilb`                  | Destroys the Internal Load Balancer.                        |
|             | `mig`                  | Destroys the Managed Instance Group.                        |
|             | `psc`                  | Destroys the PSC endpoint.                                  |
|             | `prerun`               | Destroys the core Apigee X instance.                        |
|             | `all`                  | Destroys all stages in the correct reverse order.           |
| **`--client`**  | `access`               | Opens an SSH session into the client test VM.               |
|             | `access_test_psc`      | SSH into the client and tests connectivity to the PSC endpoint. |
|             | `access_test_mig`      | SSH into the client and tests connectivity to the MIG instances. |
|             | `access_test_lb`       | SSH into the client and tests connectivity to the Load Balancer. |

## Cleanup

To destroy all resources created by the script, use the `all` stage with the `--destroy` flag.

```sh
./run.sh --project YOUR_PROJECT_ID --destroy all
```