output "cluster_api_url" {
  description = "API server endpoint for the ROSA cluster"
  value       = module.rosa_hcp.cluster_api_url
}
output "cluster_console_url" {
  description = "API server endpoint for the ROSA cluster"
  value       = module.rosa_hcp.cluster_console_url
}
output "oidc_endpoint_url" {
  description = "API server endpoint for the ROSA cluster"
  value       = module.rosa_hcp.oidc_endpoint_url
}
#output "cluster_ca_cert" {
#  description = "Base64 encoded CA cert for the ROSA cluster"
#  value       = module.rosa_hcp.
#}
output "cluster_id" {
  description = "Cluster ID for the ROSA cluster"
  value       = module.rosa_hcp.cluster_id
}
output "cluster_user_password" {
  value = module.rosa_hcp.cluster_admin_password
  sensitive = true
}
output "cluster_oidc_url" {
  value = module.rosa_hcp.oidc_endpoint_url
}
