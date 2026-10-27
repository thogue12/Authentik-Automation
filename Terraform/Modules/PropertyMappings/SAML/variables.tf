variable "name" {
  description = "Display name of the SAML property mapping (shown in the authentik admin UI)."
  type        = string
}

variable "saml_name" {
  description = "The SAML attribute name emitted in the assertion (e.g. 'IDPEmail', 'ImmutableID')."
  type        = string
}

variable "expression" {
  description = "The Python expression authentik evaluates to produce the attribute value."
  type        = string
}
