resource "authentik_provider_ws_federation" "this" {
  name               = var.name
  authorization_flow = var.authorization_flow
  invalidation_flow  = var.invalidation_flow

  reply_url = var.reply_url
  wtrealm   = var.wtrealm

  name_id_mapping   = var.name_id_mapping
  property_mappings = var.property_mappings
  signing_kp        = var.signing_kp
}
