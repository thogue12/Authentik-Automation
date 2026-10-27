variable "authorization_flow" {
  description = "ID of the authorization flow (passed from the root). Guide uses implicit-consent for zero-prompt SSO."
  type        = string
}

variable "invalidation_flow" {
  description = "ID of the invalidation flow (passed from the root)."
  type        = string
}

variable "name" {
  description = "Base display name. Provider/application/mapping names are derived from this in locals.tf."
  type        = string
  default     = "Azure Entra"
}

variable "slug" {
  description = "Application slug. Forms the federation endpoints: https://<host>/application/saml/<slug>/metadata/. Must match the slug used in the federation PowerShell script."
  type        = string
  default     = "azure-entra-app"
}

variable "reply_url" {
  description = "WS-Fed Reply URL (ACS). Fixed for Azure Entra / Microsoft online."
  type        = string
  default     = "https://login.microsoftonline.com/login.srf"
}

variable "wtrealm" {
  description = "WS-Fed Realm (audience). Fixed for Azure Entra / Microsoft online."
  type        = string
  default     = "urn:federation:MicrosoftOnline"
}

variable "idp_email_expression" {
  description = "Expression for the IDPEmail mapping."
  type        = string
  default     = "return user.attributes.get(\"upn\", user.email)"
}

variable "immutable_id_expression" {
  description = "Expression for the ImmutableID / NameID mapping. Must equal the value stored in Entra's OnPremisesImmutableId."
  type        = string
  default     = "return user.email"
}

variable "signing_kp" {
  description = "Existing certificate-key pair ID to sign assertions. Used only when create_signing_cert is false."
  type        = string
  default     = null
}

variable "create_signing_cert" {
  description = "If true, Terraform creates a dedicated signing certificate (named below) and uses it for the provider. If false, pass an existing signing_kp instead."
  type        = bool
  default     = true
}

variable "signing_cert_name" {
  description = "Name of the signing certificate created in authentik. Reference this exact name in the PowerShell federation scripts."
  type        = string
  default     = "Azure Entra WS-Fed Signing"
}

variable "signing_cert_common_name" {
  description = "Subject CN of the generated signing certificate."
  type        = string
  default     = "authentik Azure Entra WS-Fed"
}

variable "signing_cert_organization" {
  description = "Subject organization of the generated signing certificate."
  type        = string
  default     = "authentik"
}

variable "signing_cert_validity_hours" {
  description = "Validity period of the generated signing certificate, in hours. Default ~2 years."
  type        = number
  default     = 17520
}

variable "cert_output_path" {
  description = "If set, Terraform writes the signing certificate PEM to this local path (e.g. '~/Documents/Keys/authentik.pem') for the PowerShell federation scripts. Null = don't write a file."
  type        = string
  default     = null
}
