# Authentik Terraform

Infrastructure-as-code for configuring [authentik](https://goauthentik.io/) using the
[`goauthentik/authentik`](https://registry.terraform.io/providers/goauthentik/authentik/latest)
Terraform provider.

The goal is to keep the building blocks small and reusable, and to describe each real-world
integration ("platform") as a thin composition of those blocks.

---

## How it works

The project is organized into three layers. Data flows **down** (root → platform → module) and
resource IDs flow **up** (module outputs → platform outputs → root).

```
main.tf  ── calls ──▶  Platforms/<name>  ── calls ──▶  Modules/{Providers,Applications}
   ▲                                                          │
   └──────────────── outputs (IDs, URLs) ────────────────────┘
```

### 1. Modules (reusable, protocol-generic)

Each module wraps a **single** authentik resource, exposes a tidy set of variables, and outputs
its `id` so other resources can reference it. Modules know nothing about any specific vendor.

| Module | Resource | Purpose |
| --- | --- | --- |
| `Modules/Providers/SAML` | `authentik_provider_saml` | SAML SSO provider |
| `Modules/Providers/WS-Federation` | `authentik_provider_ws_federation` | WS-Federation provider (e.g. Entra login) |
| `Modules/Providers/OATH2` | `authentik_provider_oauth2` | OAuth2 / OIDC provider |
| `Modules/Providers/SCIM` | `authentik_provider_scim` | SCIM provisioning provider |
| `Modules/Providers/MicrosoftEntra` | `authentik_provider_microsoft_entra` | Entra ID sync/provisioning |
| `Modules/PropertyMappings/SAML` | `authentik_property_mapping_provider_saml` | A SAML attribute/NameID mapping |
| `Modules/Applications` | `authentik_application` | The application users see/launch |

### 2. Platforms (opinionated, one per integration)

A platform represents "integrate authentik with product X" (this is what authentik's own docs call
an *integration*). Each platform is itself a module that calls one or more provider modules plus the
application module, wiring in that vendor's specific settings (ACS URLs, audiences, client IDs, etc.).

Current platform: `Entra`, (`HCP`, `TrueNas` to come) (inbound WS-Fed
login).

> **Two Microsoft directions, two platforms.** `Entra` is **outbound** — authentik provisions users
> and groups *into* Entra via the Microsoft Entra backchannel provider (the `registerApp.ps1`
> equivalent). `AzureEntra` is **inbound** — authentik acts as the IdP so users log *into* Microsoft
> Entra / Azure through authentik via WS-Federation. They are independent.

### 3. Root (`main.tf` and friends)

The root configures the provider once and calls the platforms. Key root files:

| File | Responsibility |
| --- | --- |
| `provider.tf` | `required_providers` + the `authentik` provider block |
| `variables.tf` | `authentik_url` / `authentik_token` and all per-platform inputs |
| `data.tf` | Looks up the default **authorization** and **invalidation** flows once |
| `locals.tf` | Derives `authentik_host` from the provider URL |
| `main.tf` | Instantiates the platform module(s) |
| `outputs.tf` | Surfaces platform outputs (e.g. the signing cert name/PEM) |
| `terraform.tfvars` | Your actual values (git-ignored — see below) |

#### Instantiating a platform

The root calls each platform module directly and passes the shared flow IDs plus that platform's
inputs:

```hcl
module "azure_entra" {
  source = "./Platforms/AzureEntra"

  authorization_flow = data.authentik_flow.default_authorization.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id

  name = var.azure_entra_name
  slug = var.azure_entra_slug
  # ...platform inputs...
}
```


#### Shared flows

Every authentik provider requires an `authorization_flow` and an `invalidation_flow`. Rather than
look these up in every module, `data.tf` resolves the shipped defaults once and the root passes the
IDs down into each platform.

---

## Usage

1. Copy the example vars and fill in your authentik URL + API token:

   ```bash
   cp terraform.tfvars.example terraform.tfvars   # if an example file exists
   # otherwise edit terraform.tfvars directly
   ```

2. Enable the platforms you want and provide their values in `terraform.tfvars`.

3. Run:

   ```bash
   terraform init
   terraform fmt -recursive
   terraform validate
   terraform plan
   terraform apply
   ```

### Secrets & git

The `.gitignore` deliberately excludes `*.tfvars`, `*.tfstate*`, `*.tfplan`, and key material,
because state and vars hold the authentik token and client secrets in plaintext. Commit a
`*.tfvars.example` with placeholder values instead of the real `terraform.tfvars`.

---

## Frontchannel vs. backchannel providers

This distinction decides how you wire a provider into an application:

- **Frontchannel** (SAML, OAuth2/OIDC): the provider handles the login redirect. Attach it via the
  application's `protocol_provider`.
- **Backchannel** (SCIM, Microsoft Entra): the provider syncs/provisions in the background. Leave
  `protocol_provider = null` and attach it via `backchannel_providers = [<id>]`.

---

## How to add things

### Add a new platform (most common)

Say you want to integrate **Grafana** over OAuth2.

1. **Create the directory and three files:**

   ```
   Platforms/Grafana/
     main.tf
     variables.tf
     outputs.tf
   ```

2. **`variables.tf`** — declare the flow IDs the root will pass in, plus the vendor-specific inputs:

   ```hcl
   variable "authorization_flow" { type = string }
   variable "invalidation_flow"  { type = string }

   variable "client_id"     { type = string }
   variable "client_secret" { type = string, default = null, sensitive = true }
   variable "redirect_uris" {
     type    = list(map(string))
     default = []
   }
   variable "name" { type = string, default = "Grafana" }
   variable "slug" { type = string, default = "grafana" }
   ```

3. **`main.tf`** — call the provider module + the application module:

   ```hcl
   module "oauth2_provider" {
     source = "../../Modules/Providers/OATH2"

     name                  = var.name
     client_id             = var.client_id
     authorization_flow    = var.authorization_flow
     invalidation_flow     = var.invalidation_flow
     client_secret         = var.client_secret
     allowed_redirect_uris = var.redirect_uris
   }

   module "application" {
     source = "../../Modules/Applications"

     name              = var.name
     slug              = var.slug
     protocol_provider = module.oauth2_provider.id
   }
   ```

4. **`outputs.tf`** — surface anything you'll need on the vendor side:

   ```hcl
   output "client_id" { value = module.oauth2_provider.client_id }
   output "client_secret" {
     value     = module.oauth2_provider.client_secret
     sensitive = true
   }
   output "application_slug" { value = module.application.slug }
   ```

5. **Wire it into the root** `main.tf`:

   ```hcl
   module "grafana" {
     source = "./Platforms/Grafana"

     authorization_flow = data.authentik_flow.default_authorization.id
     invalidation_flow  = data.authentik_flow.default_invalidation.id

     client_id     = var.grafana_client_id
     client_secret = var.grafana_client_secret
     redirect_uris = var.grafana_redirect_uris
   }
   ```

6. **Add the root variables** in `variables.tf`:

   ```hcl
   variable "grafana_client_id"     { type = string, default = null }
   variable "grafana_client_secret" { type = string, default = null, sensitive = true }
   variable "grafana_redirect_uris" {
     type    = list(map(string))
     default = []
   }
   ```

7. **Set values** in `terraform.tfvars`, then `terraform plan`.

> **Tip:** follow the authentik integration guide for the product (https://integrations.goauthentik.io/)
> to know which protocol to use and which fields (ACS URL, audience, redirect URIs, etc.) it needs.

### Add a new provider type

If you want to add another provider this project doesn't wrap yet (e.g. LDAP, RAC, RADIUS):

1. Create `Modules/Providers/<Name>/` with `main.tf`, `variables.tf`, `outputs.tf`.
2. In `main.tf`, declare the single `authentik_provider_<type>` resource. Check the required vs.
   optional arguments in the provider docs:
   `https://registry.terraform.io/providers/goauthentik/authentik/latest/docs` (the raw markdown
   lives under `goauthentik/terraform-provider-authentik/docs/resources/` on GitHub).
3. Expose `name` + the required fields as variables; give optional fields sensible defaults.
4. Always output `id` (platforms need it to attach the provider to an application).
5. Use the new module from a platform exactly like the existing ones.

### Add just an application

The `Modules/Applications` module is already generic. Call it directly from a platform (or a new
one) and pass `protocol_provider` (frontchannel) and/or `backchannel_providers` (backchannel):

```hcl
module "application" {
  source = "../../Modules/Applications"

  name                  = "My App"
  slug                  = "my-app"
  protocol_provider     = module.some_provider.id   # frontchannel
  backchannel_providers = [module.scim_provider.id] # backchannel (optional)
  meta_launch_url       = "https://my-app.company/"
}
```

### Add a reusable sub-resource (property mappings, policies, bindings, etc.)

Integration guides often require extra objects — SAML property mappings, policy bindings, OAuth
scope mappings. Two options:

- **Local to one platform:** declare the resource directly inside that platform's `main.tf` and
  pass its `.id` into the provider/application module (e.g. a SAML provider's `property_mappings`).
- **Reused across platforms:** wrap it in its own module under `Modules/` and call it wherever
  needed, same as the provider modules.

---

---

## Azure Entra — inbound WS-Federation login (`Platforms/AzureEntra`)

This platform codifies the hand-built WS-Fed federation proven out via the PowerShell scripts in
`../ConnectEntra-Authentik`. It creates the two required SAML property mappings, a dedicated signing
certificate, a WS-Federation provider, and the application.

Configure it in `terraform.tfvars` (sensible defaults mean you usually only set a few values):

```hcl
azure_entra_name = "Azure Entra"
azure_entra_slug = "azure-entra-app"   # issuer becomes .../application/saml/azure-entra-app/metadata/

# Optional: write the generated signing cert PEM to a path for the PowerShell scripts.
azure_entra_cert_output_path = "~/Documents/Keys/authentik.pem"
```

### What it builds

| Resource | Notes |
| --- | --- |
| `ImmutableID` property mapping | NameID. Expression defaults to `return user.email` (cloud-only). |
| `IDPEmail` property mapping | Defaults to `return user.attributes.get("upn", user.email)`. |
| Signing certificate | Generated via the `tls` provider and uploaded as an `authentik_certificate_key_pair` with a name you control (`azure_entra_signing_cert_name`). |
| WS-Federation provider | `authentik_provider_ws_federation`: Reply URL = `https://login.microsoftonline.com/login.srf`, Realm = `urn:federation:MicrosoftOnline`, NameID = the ImmutableID mapping. |
| Application | `protocol_provider` = the WS-Fed provider. No launch URL (left blank). |

### Certificate handling

By default (`azure_entra_create_signing_cert = true`) Terraform generates the signing cert and wires
it into the provider no manual "download from the UI" step. Retrieve it after apply:

```bash
terraform output -raw azure_entra_signing_cert_pem > authentik.pem
terraform output azure_entra_signing_cert_name
```
To set the file path to a specific or desired location edit the terraform.tfvars file in the root

```bash
Windows

 azure_entra_cert_output_path = "C:/Users/yourusername/Documents/Keys/authentik.pem"

```

```bash
Mac/Linux

  azure_entra_cert_output_path = "~/Documents/Keys/authentik.pem"

```
Or set `azure_entra_cert_output_path` and Terraform writes the PEM to that path automatically. To use
an existing cert instead, set `azure_entra_create_signing_cert = false` and pass `signing_kp`.



## Conventions

- One resource per module; always output its `id`.
- Sub-modules and platforms declare only a `terraform { required_providers }` block — **no**
  `provider "authentik"` block. The provider is configured once at the root and inherited. (A module
  with its own provider block is a "legacy module" and cannot be used with `count` / `for_each` /
  `depends_on`, so keep provider config at the root.)
- Required arguments become required variables; optional arguments get defaults (`null`, `false`,
  `[]`) so platforms only set what they care about.
- Mark secrets (`client_secret`, `token`, API tokens) with `sensitive = true`.
- Reference module outputs, never hard-coded IDs, so Terraform tracks dependencies.
- Keep vendor-specific values in platforms, not in the generic modules.

