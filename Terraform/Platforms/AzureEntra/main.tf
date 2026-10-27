
module "mapping_idp_email" {
  source = "../../Modules/PropertyMappings/SAML"

  name       = local.idp_email_name
  saml_name  = "IDPEmail"
  expression = var.idp_email_expression
}

module "mapping_immutable_id" {
  source = "../../Modules/PropertyMappings/SAML"

  name       = local.immutable_id_name
  saml_name  = "ImmutableID"
  expression = var.immutable_id_expression
}

module "provider" {
  source = "../../Modules/Providers/WS-Federation"

  name               = local.provider_name
  authorization_flow = var.authorization_flow
  invalidation_flow  = var.invalidation_flow

  reply_url = var.reply_url
  wtrealm   = var.wtrealm

  name_id_mapping = module.mapping_immutable_id.id
  property_mappings = [
    module.mapping_idp_email.id,
    module.mapping_immutable_id.id,
  ]

  signing_kp = var.create_signing_cert ? authentik_certificate_key_pair.signing[0].id : var.signing_kp
}

module "application" {
  source = "../../Modules/Applications"

  name              = local.application_name
  slug              = var.slug
  protocol_provider = module.provider.id
}
