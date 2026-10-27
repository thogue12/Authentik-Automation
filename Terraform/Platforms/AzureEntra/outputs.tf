output "provider_id" {
  description = "ID of the WS-Federation provider."
  value       = module.provider.id
}

output "application_slug" {
  description = "Slug of the application. Issuer/metadata URL = https://<host>/application/saml/<slug>/metadata/."
  value       = module.application.slug
}

output "idp_email_mapping_id" {
  description = "ID of the IDPEmail property mapping."
  value       = module.mapping_idp_email.id
}

output "immutable_id_mapping_id" {
  description = "ID of the ImmutableID property mapping."
  value       = module.mapping_immutable_id.id
}

output "signing_cert_name" {
  description = "Name of the signing certificate in authentik. Reference this in the PowerShell federation scripts."
  value       = var.create_signing_cert ? var.signing_cert_name : null
}

output "signing_cert_pem" {
  description = "PEM of the generated signing certificate. Feed this to the Entra federation config (strip header/footer/whitespace)."
  value       = var.create_signing_cert ? tls_self_signed_cert.signing[0].cert_pem : null
}
