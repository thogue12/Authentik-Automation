output "id" {
  description = "ID of the WS-Federation provider, used as an application's protocol_provider."
  value       = authentik_provider_ws_federation.this.id
}

output "name" {
  description = "Name of the WS-Federation provider."
  value       = authentik_provider_ws_federation.this.name
}
