output "azure_entra_application_slug" {
  description = "Slug of the Azure Entra application. Issuer/metadata URL = https://<host>/application/saml/<slug>/metadata/."
  value       = module.azure_entra.application_slug
}

output "azure_entra_signing_cert_name" {
  description = "Name of the signing certificate in authentik. Reference this in the PowerShell federation scripts."
  value       = module.azure_entra.signing_cert_name
}

output "azure_entra_signing_cert_pem" {
  description = "PEM of the generated signing certificate. Supply this to the Entra federation config."
  value       = module.azure_entra.signing_cert_pem
}
