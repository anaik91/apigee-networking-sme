/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  target_xml = <<EOF
  <TargetEndpoint name="default">
  <PreFlow name="PreFlow">
    <Request/>
    <Response/>
  </PreFlow>
  <Flows/>
  <PostFlow name="PostFlow">
    <Request/>
    <Response/>
  </PostFlow>
  <HTTPTargetConnection>
    <Properties/>
    <URL>http://${var.nginx_ip}</URL>
  </HTTPTargetConnection>
</TargetEndpoint>
EOF
}

resource "local_file" "update_apiproxy_target" {
  content  = local.target_xml
  filename = "${path.module}/api_proxy/apiproxy/targets/default.xml"
}

data "archive_file" "api_proxy" {
  type             = "zip"
  source_dir       = "${path.module}/api_proxy"
  output_path      = "${path.module}/${var.nginx_api_proxy_name}.zip"
  output_file_mode = "0644"
  depends_on       = [local_file.update_apiproxy_target]
}

resource "google_apigee_api" "api_proxy" {
  name          = var.nginx_api_proxy_name
  org_id        = var.project_id
  config_bundle = data.archive_file.api_proxy.output_path
}

resource "local_file" "deploy_apiproxy_file" {
  content = templatefile("${path.module}/deploy-apiproxy.sh.tpl", {
    organization = var.project_id
    environment  = var.deploy_env
    api_name     = var.nginx_api_proxy_name
  })
  filename        = "${path.module}/deploy-apiproxy.sh"
  file_permission = "0755"
}
