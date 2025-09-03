output "google_apigee_endpoint_attachment_ip" {
  value = google_apigee_endpoint_attachment.swp.host
}

output "forward_proxy_url" {
  value = "http://${google_apigee_endpoint_attachment.swp.host}:8080"
}