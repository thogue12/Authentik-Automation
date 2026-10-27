variable "authentik_url" {
  description = "Base URL of the authentik installation (e.g. https://authentik.company)."
  type        = string
}

variable "authentik_token" {
  description = "API token used to authenticate against authentik."
  type        = string
  sensitive   = true
}

# --- Shared ---

variable "signing_kp" {
  description = "Existing certificate-key pair ID to sign assertions. Used only when azure_entra_create_signing_cert is false."
  type        = string
  default     = null
}

# --- Azure Entra (WS-Fed inbound login) ---

variable "azure_entra_name" {
  description = "Base display name for the Azure Entra application and provider."
  type        = string
  default     = "Azure Entra"
}

variable "azure_entra_slug" {
  description = "Application slug. Issuer/metadata URL = https://<host>/application/saml/<slug>/metadata/."
  type        = string
  default     = "azure-entra-app"
}

variable "azure_entra_immutable_id_expression" {
  description = "ImmutableID/NameID expression. Must resolve to the user's OnPremisesImmutableId in Entra. Cloud-only: 'return user.email'."
  type        = string
  default     = "return user.email"
}

variable "azure_entra_create_signing_cert" {
  description = "If true, Terraform creates a dedicated signing certificate and uses it. If false, provide signing_kp."
  type        = bool
  default     = true
}

variable "azure_entra_signing_cert_name" {
  description = "Name of the signing certificate created in authentik. Reference this exact name in the PowerShell federation scripts."
  type        = string
  default     = "Azure Entra WS-Fed Signing"
}

variable "azure_entra_cert_output_path" {
  description = "If set, Terraform writes the signing cert PEM to this local path for the PowerShell scripts (e.g. '~/Documents/Keys/authentik.pem'). Null = don't write a file."
  type        = string
  default     = null
}



# --- HCP ---

variable "hcp_sso_sign_on_url" {
  description = "HCP 'SSO Sign-On URL' (used as the SAML ACS URL)."
  type        = string
  default     = null
}

variable "hcp_entity_id" {
  description = "HCP 'Entity ID' (used as the SAML audience)."
  type        = string
  default     = null
}


