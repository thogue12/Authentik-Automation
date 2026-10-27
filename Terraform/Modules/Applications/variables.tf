variable "name" {
  description = "Display name of the application."
  type        = string
}

variable "slug" {
  description = "URL slug for the application."
  type        = string
}

variable "protocol_provider" {
  description = "ID of the frontchannel provider (e.g. SAML or OAuth2) to attach. Leave null for backchannel-only apps like Entra ID."
  type        = number
  default     = null
}

variable "backchannel_providers" {
  description = "List of backchannel provider IDs to attach (e.g. SCIM, Microsoft Entra)."
  type        = list(number)
  default     = []
}

variable "group" {
  description = "Optional group used to categorize the application in the UI."
  type        = string
  default     = null
}

variable "meta_launch_url" {
  description = "URL users are sent to when launching the application."
  type        = string
  default     = null
}

variable "meta_description" {
  description = "Optional description shown on the application."
  type        = string
  default     = null
}

variable "meta_icon" {
  description = "Optional icon URL for the application."
  type        = string
  default     = null
}

variable "meta_publisher" {
  description = "Optional publisher name for the application."
  type        = string
  default     = null
}

variable "open_in_new_tab" {
  description = "Whether the application opens in a new browser tab."
  type        = bool
  default     = false
}

variable "policy_engine_mode" {
  description = "How policies are evaluated: 'any' or 'all'."
  type        = string
  default     = "any"
}
