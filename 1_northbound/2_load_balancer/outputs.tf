output "address" {
  description = "Forwarding rule address."
  value       = [for _, value in module.ilb-l7 : value.address]
}