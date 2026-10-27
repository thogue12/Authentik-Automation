resource "authentik_property_mapping_provider_saml" "this" {
  name       = var.name
  saml_name  = var.saml_name
  expression = var.expression
}
