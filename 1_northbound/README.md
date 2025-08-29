# Apigee X Terraform Deployment

This repository contains Terraform code to deploy Apigee X.

## Project Structure

*   **`0_pre_run/`**: This directory contains the root Terraform module for deploying Apigee X. It uses the `apigee-x-core` module to create the necessary resources.
*   **`modules/apigee-x-core/`**: This directory contains a reusable Terraform module that creates the Apigee X organization, instances, and environments. It also creates the necessary KMS keys for encryption.

## Prerequisites

*   [Terraform](https://www.terraform.io/downloads.html)
*   [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
*   An active Google Cloud project with billing enabled.

## Deployment

1.  **Initialize Terraform:**
    ```bash
    terraform -chdir=0_pre_run init
    ```
2.  **Review the plan:**
    ```bash
    terraform -chdir=0_pre_run plan
    ```
3.  **Apply the changes:**
    ```bash
    terraform -chdir=0_pre_run apply
    ```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project\_id | The Google Cloud project ID. | `string` | n/a | yes |
| ax\_region | The GCP region for storing Apigee analytics data. | `string` | n/a | yes |
| apigee\_instances | A map of Apigee instances to create. | `map(object)` | `{}` | no |
| apigee\_envgroups | A map of Apigee environment groups to create. | `map(object)` | `{}` | no |
| apigee\_environments | A map of Apigee environments to create. | `map(object)` | `null` | no |

## Outputs

This module does not produce any outputs.
