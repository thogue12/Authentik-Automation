variable "name" {
  description = "Name of the WS-Federation provider."
  type        = string
}

variable "reply_url" {
  description = "WS-Fed Reply URL (assertion consumer endpoint). For Microsoft 365: https://login.microsoftonline.com/login.srf."
  type        = string
  default     = "https://login.microsoftonline.com/login.srf"
}

variable "wtrealm" {
  description = "WS-Fed Realm / audience. For Microsoft 365: urn:federation:MicrosoftOnline."
  type        = string
  default     = "urn:federation:MicrosoftOnline"
}

variable "authorization_flow" {
  description = "ID of the authorization flow used by this provider."
  type        = string
}

variable "invalidation_flow" {
  description = "ID of the invalidation (logout) flow used by this provider."
  type        = string
}

variable "name_id_mapping" {
  description = "ID of the property mapping used for the NameID (Microsoft 365: the ImmutableID mapping)."
  type        = string
  default     = null
}

variable "property_mappings" {
  description = "List of property mapping IDs to include. Setting this replaces authentik's default selection."
  type        = list(string)
  default     = []
}

variable "signing_kp" {
  description = "ID of the certificate-key pair used to sign assertions."
  type        = string
  default     = null
}
