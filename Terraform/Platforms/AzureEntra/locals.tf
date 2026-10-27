locals {
  provider_name     = "${var.name} WS-Fed Provider"
  application_name  = var.name
  idp_email_name    = "${var.name} IDPEmail"
  immutable_id_name = "${var.name} Immutable ID"
}
