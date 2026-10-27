resource "authentik_application" "this" {
  name = var.name
  slug = var.slug

  protocol_provider     = var.protocol_provider
  backchannel_providers = var.backchannel_providers

  group              = var.group
  meta_launch_url    = var.meta_launch_url
  meta_description   = var.meta_description
  meta_icon          = var.meta_icon
  meta_publisher     = var.meta_publisher
  open_in_new_tab    = var.open_in_new_tab
  policy_engine_mode = var.policy_engine_mode
}
