# Apigee X Terraform

This Terraform module sets up a basic Apigee X organization.

## Prerequisites

*   Terraform v1.0+
*   Google Cloud SDK
*   Authenticated as a user with permissions to create the resources described below.

## Usage

1.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

2.  **Review the plan:**
    ```bash
    terraform plan
    ```

3.  **Apply the changes:**
    ```bash
    terraform apply
    ```

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | --- |
| `project_id` | Project id (also used for the Apigee Organization). | `string` | n/a | yes |
| `billing_account` | Billing account id. | `string` | `null` | no |
| `project_create` | Create project. When set to false, uses a data source to reference existing project. | `bool` | `false` | no |
| `project_parent` | Parent folder or organization in 'folders/folder\_id' or 'organizations/org\_id' format. | `string` | `null` | no |
| `ax_region` | GCP region for storing Apigee analytics data. | `string` | n/a | yes |
| `apigee_instances` | Apigee Instances (only one instance for EVAL orgs). | `map(object({ region = string, environments = list(string) }))` | `null` | no |
| `apigee_envgroups` | Apigee Environment Groups. | `map(object({ hostnames = list(string) }))` | `null` | no |
| `apigee_environments` | Apigee Environments. | `map(object({ display_name = optional(string), description = optional(string), node_config = optional(object({ min_node_count = optional(number), max_node_count = optional(number) })), iam = optional(map(list(string))), envgroups = list(string), type = optional(string) }))` | `null` | no |

## Outputs

No outputs are defined.

## Resource Diagram

```mermaid
graph TD
    subgraph "Google Cloud Project"
        direction LR
        GCP_PROJECT[("project_id: ci-cloud-spanner-c06d")]
    end

    subgraph "Enabled Services"
        direction LR
        SERVICE1[apigee.googleapis.com]
        SERVICE2[cloudkms.googleapis.com]
        SERVICE3[compute.googleapis.com]
    end

    subgraph "Apigee X"
        direction TB
        APIGEE_ORG("Apigee Organization")
        APIGEE_INSTANCE["Instance: usw1-instance (europe-west2)"]
        subgraph "Environments"
            direction LR
            ENV1["test1"]
            ENV2["test2"]
        end
        subgraph "Environment Groups"
            direction LR
            ENV_GROUP["test"]
        end
        HOSTNAME["hostname: test.api.example.com"]
        API_PROXY["API Proxy: mock"]
    end

    GCP_PROJECT --> SERVICE1
    GCP_PROJECT --> SERVICE2
    GCP_PROJECT --> SERVICE3
    GCP_PROJECT --> APIGEE_ORG
    APIGEE_ORG --> APIGEE_INSTANCE
    APIGEE_INSTANCE --> ENV1
    APIGEE_INSTANCE --> ENV2
    ENV1 --> ENV_GROUP
    ENV2 --> ENV_GROUP
    ENV_GROUP --> HOSTNAME
    APIGEE_ORG --> API_PROXY
    API_PROXY --> ENV1
```
