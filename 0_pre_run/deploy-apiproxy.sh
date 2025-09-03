#!/bin/bash

API_NAME=mock
ORGANIZATION=ci-cloud-spanner-c06d
ENVIRONMENT=test1

export TOKEN=$(gcloud auth print-access-token)

curl -v -X POST \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type:application/octet-stream" \
-T 'bundle.zip' \
"https://apigee.googleapis.com/v1/organizations/$ORGANIZATION/apis?name=$API_NAME&action=import"

curl -v -X POST \
-H "Authorization: Bearer $TOKEN" \
"https://apigee.googleapis.com/v1/organizations/$ORGANIZATION/environments/$ENVIRONMENT/apis/$API_NAME/revisions/1/deployments"

curl -v \
-H "Authorization: Bearer $TOKEN" \
"https://apigee.googleapis.com/v1/organizations/$ORGANIZATION/environments/$ENVIRONMENT/apis/$API_NAME/revisions/1/deployments"