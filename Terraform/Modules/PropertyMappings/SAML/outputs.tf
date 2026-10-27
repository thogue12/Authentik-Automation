output "id" {
  description = "ID of the SAML property mapping. Pass to a provider's name_id_mapping or property_mappings."
  value       = authentik_property_mapping_provider_saml.this.id
}

output "name" {
  description = "Name of the SAML property mapping."
  value       = authentik_property_mapping_provider_saml.this.name
}
