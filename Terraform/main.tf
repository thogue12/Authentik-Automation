module "azure_entra" {
  source = "./Platforms/AzureEntra"

  authorization_flow = data.authentik_flow.default_authorization.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id

  name = var.azure_entra_name
  slug = var.azure_entra_slug

  create_signing_cert = var.azure_entra_create_signing_cert
  signing_cert_name   = var.azure_entra_signing_cert_name
  signing_kp          = var.signing_kp
  cert_output_path    = var.azure_entra_cert_output_path

  immutable_id_expression = var.azure_entra_immutable_id_expression
}
