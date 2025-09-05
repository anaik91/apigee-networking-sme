# Auto-generated from defaults.toml. Do not edit manually.

ax_region           = "europe-west2"
mock_api_proxy_name = "mock"
forward_proxy_url   = ""
apigee_instances = {
  euw2-instance = {
    region = "europe-west2"
    environments = [
      "test1",
      "test2"
    ]
  }
}
apigee_envgroups = {
  test = {
    hostnames = [
      "test.api.example.com"
    ]
  }
}
apigee_environments = {
  test1 = {
    display_name = "Test 1"
    description  = "Environment created by apigee/terraform-modules"
    envgroups = [
      "test"
    ]
  }
  test2 = {
    display_name = "Test 2"
    description  = "Environment created by apigee/terraform-modules"
    envgroups = [
      "test"
    ]
  }
}
