variable "name" {
  description = "Name of the SAML provider."
  type        = string
}

variable "authorization_flow" {
  description = "ID of the authorization flow used by this provider."
  type        = string
}

variable "invalidation_flow" {
  description = "ID of the invalidation (logout) flow used by this provider."
  type        = string
}

variable "acs_url" {
  description = "Assertion Consumer Service URL provided by the service provider."
  type        = string
}

variable "audience" {
  description = "Expected audience / Entity ID of the service provider."
  type        = string
  default     = null
}

variable "sls_url" {
  description = "Single Logout Service URL of the service provider."
  type        = string
  default     = null
}

variable "sls_binding" {
  description = "Binding used for Single Logout: 'redirect' or 'post'."
  type        = string
  default     = "redirect"
}

variable "logout_method" {
  description = "Logout method: 'frontchannel_iframe', 'frontchannel_native', or 'backchannel'."
  type        = string
  default     = "frontchannel_iframe"
}

variable "issuer_override" {
  description = "Override the default issuer (EntityID). Leave null to use the authentik default."
  type        = string
  default     = null
}

variable "name_id_mapping" {
  description = "ID of the property mapping used for the SAML NameID."
  type        = string
  default     = null
}

variable "authn_context_class_ref_mapping" {
  description = "ID of the property mapping used for AuthnContextClassRef (e.g. the Microsoft 365 MFA claim). Null to omit."
  type        = string
  default     = null
}

variable "property_mappings" {
  description = "List of SAML property mapping IDs to include in assertions."
  type        = list(string)
  default     = []
}

variable "signing_kp" {
  description = "ID of the certificate-key pair used to sign assertions."
  type        = string
  default     = null
}

variable "digest_algorithm" {
  description = "Digest algorithm for the assertion signature. Microsoft 365 expects SHA256."
  type        = string
  default     = "http://www.w3.org/2001/04/xmlenc#sha256"
}

variable "signature_algorithm" {
  description = "Signature algorithm for the assertion. Microsoft 365 expects RSA-SHA256."
  type        = string
  default     = "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"
}

variable "assertion_valid_not_before" {
  description = "How long before 'now' the assertion is valid (ISO8601 duration, e.g. 'minutes=-5'). Null = authentik default."
  type        = string
  default     = null
}

variable "assertion_valid_not_on_or_after" {
  description = "How long after 'now' the assertion stays valid (e.g. 'minutes=5'). Null = authentik default."
  type        = string
  default     = null
}

variable "session_valid_not_on_or_after" {
  description = "How long the session assertion stays valid (e.g. 'minutes=86400'). Null = authentik default."
  type        = string
  default     = null
}
