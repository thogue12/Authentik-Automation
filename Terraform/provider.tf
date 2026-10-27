terraform {
  required_version = ">= 1.5.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2026.8"
    }
  }
}

provider "authentik" {
  url   = var.authentik_url
  token = var.authentik_token
}