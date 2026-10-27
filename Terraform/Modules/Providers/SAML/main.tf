resource "authentik_provider_saml" "this" {
  name               = var.name
  authorization_flow = var.authorization_flow
  invalidation_flow  = var.invalidation_flow

  acs_url     = var.acs_url
  audience    = var.audience
  sls_url     = var.sls_url
  sls_binding = var.sls_binding

  logout_method   = var.logout_method
  issuer_override = var.issuer_override

  name_id_mapping                 = var.name_id_mapping
  authn_context_class_ref_mapping = var.authn_context_class_ref_mapping
  property_mappings               = var.property_mappings
  signing_kp                      = var.signing_kp

  digest_algorithm    = var.digest_algorithm
  signature_algorithm = var.signature_algorithm

  assertion_valid_not_before      = var.assertion_valid_not_before
  assertion_valid_not_on_or_after = var.assertion_valid_not_on_or_after
  session_valid_not_on_or_after   = var.session_valid_not_on_or_after
}
