resource "tls_private_key" "signing" {
  count     = var.create_signing_cert ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "signing" {
  count           = var.create_signing_cert ? 1 : 0
  private_key_pem = tls_private_key.signing[0].private_key_pem

  subject {
    common_name  = var.signing_cert_common_name
    organization = var.signing_cert_organization
  }

  validity_period_hours = var.signing_cert_validity_hours

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
  ]
}

resource "authentik_certificate_key_pair" "signing" {
  count            = var.create_signing_cert ? 1 : 0
  name             = var.signing_cert_name
  certificate_data = tls_self_signed_cert.signing[0].cert_pem
  key_data         = tls_private_key.signing[0].private_key_pem
}

resource "local_file" "signing_cert_pem" {
  count           = var.create_signing_cert && var.cert_output_path != null ? 1 : 0
  filename        = pathexpand(var.cert_output_path)
  content         = tls_self_signed_cert.signing[0].cert_pem
  file_permission = "0600"
}
