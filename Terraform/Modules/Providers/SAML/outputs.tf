output "id" {
  description = "ID of the SAML provider, used as an application's protocol_provider."
  value       = authentik_provider_saml.this.id
}

output "name" {
  description = "Name of the SAML provider."
  value       = authentik_provider_saml.this.name
}

output "url_sso_post" {
  description = "SSO URL (HTTP-POST binding) for this provider."
  value       = authentik_provider_saml.this.url_sso_post
}

output "url_sso_redirect" {
  description = "SSO URL (HTTP-Redirect binding) for this provider."
  value       = authentik_provider_saml.this.url_sso_redirect
}
