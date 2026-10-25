# Authentik ↔ Microsoft Entra ID — PowerShell Scripts

This folder contains PowerShell scripts that automate connecting **authentik** with **Microsoft Entra ID**, covering app registration, domain federation, and user identity setup.

The scripts fall into two groups by the tool they depend on:

| Dependency | Scripts |
|---|---|
| **Azure CLI (`az`)** | `registerApp.ps1`, `deleteSvp.ps1` |
| **Microsoft Graph PowerShell SDK** | `autoDomainFederation.ps1`, `revertDomainFederation.ps1`, `updateFederationIssuer.ps1`, `federatedID.ps1`, `immutableID.ps1` |

> **Safety note:** The federation scripts change how **every user on a domain** signs in. Always keep a break-glass admin account on a non-federated domain (such as the tenant's `*.onmicrosoft.com`) before federating.

---

## Prerequisites

### 1. PowerShell 7+

All scripts target PowerShell 7 (`pwsh`), not Windows PowerShell 5.1.

```bash
pwsh --version
```

Install it from [the PowerShell releases page](https://github.com/PowerShell/PowerShell/releases) or via a package manager (`brew install powershell`, `winget install Microsoft.PowerShell`, etc.).

### 2. Azure CLI — for `registerApp.ps1` and `deleteSvp.ps1`

```bash
# macOS
brew install azure-cli

# Verify, then sign in
az --version
az login
```

### 3. Microsoft Graph PowerShell SDK — for the federation/identity scripts

The full `Microsoft.Graph` meta-module is large (~40 sub-modules) and a full install can fail mid-download. The scripts only use three sub-modules, so installing just those is faster and more reliable:

```powershell
Install-Module Microsoft.Graph.Authentication                -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.DirectoryManagement  -Scope CurrentUser
Install-Module Microsoft.Graph.Users                         -Scope CurrentUser
```

Verify they're present:

```powershell
Get-Module -ListAvailable Microsoft.Graph.Authentication,
    Microsoft.Graph.Identity.DirectoryManagement,
    Microsoft.Graph.Users | Select-Object Name, Version
```

| Cmdlets used | Provided by |
|---|---|
| `Connect-MgGraph`, `Get-MgContext` | `Microsoft.Graph.Authentication` |
| `Get-MgDomain`, `*-MgDomainFederationConfiguration` | `Microsoft.Graph.Identity.DirectoryManagement` |
| `Get-MgUser`, `Update-MgUser` | `Microsoft.Graph.Users` |



---


### `autoDomainFederation.ps1` — federate a domain to authentik (Graph SDK)

**Dry run by default — makes no changes unless you opt in.** Echoes the connected tenant/account, verifies the domain, and builds all WS-Fed endpoints from the authentik host + slug.

**Parameters**

| Parameter | Notes |
|---|---|
| `-DomainName` | **Required.** The verified Entra domain to federate. |
| `-AuthentikHost` | **Required.** authentik FQDN, no scheme (e.g. `dsb-hub.xyz`). |
| `-Slug` | **Required.** authentik application slug (e.g. `azure-entra-app`). |
| `-CertificatePath` | **Required.** Path to the PEM signing certificate downloaded from the authentik WS-Fed provider. |
| `-ExpectedTenantId` | Recommended. Aborts if the connected tenant differs; also targets sign-in to this tenant. |
| `-FederatedIdpMfaBehavior` | Defaults to `acceptIfMfaDoneByFederatedIdp`. |
| `-Force` | Replace an existing federation config. |
| `-Execute` | **Required to make changes.** Omitted = dry run. |

**How to run**

`-Execute` is a real command-line switch — no file editing needed:

```powershell
# Dry run (default) — prints exactly what it would do, writes nothing
./autoDomainFederation.ps1

# Apply, after reviewing the dry-run output
./autoDomainFederation.ps1 -Execute

# Apply and replace an existing federation config
./autoDomainFederation.ps1 -Execute -Force

* Go into the powershell script to edit the parameters at the top
```

A browser opens for interactive sign-in. Sign in with an admin account **belonging to the expected tenant**.

> Download the signing certificate first: authentik Admin → **Applications → Providers** → your WS-Fed provider → **Related objects → Download signing certificate**.

**WS-Federation URL layout**

The script builds the five federation endpoints from `-AuthentikHost` + `-Slug`, following the [official authentik Microsoft 365 WS-Federation guide](https://integrations.goauthentik.io/platforms/microsoft-ws-federation). Note that **passive and active sign-in use the bare `/application/wsfed/` path (no slug)**, while sign-out, issuer, and metadata-exchange include the slug:

| Federation field | URL pattern |
|---|---|
| PassiveSignInUri | `https://<host>/application/wsfed/` |
| ActiveSignInUri | `https://<host>/application/wsfed/` |
| SignOutUri | `https://<host>/application/wsfed/<slug>/` |
| IssuerUri | `https://<host>/application/saml/<slug>/metadata/` |
| MetadataExchangeUri | `https://<host>/application/wsfed/<slug>/metadata/` |

> The **IssuerUri** must equal the provider's `entityID` (the SAML metadata URL), **not** the wsfed path. Verify against your provider's metadata (Applications → Providers → your provider → Metadata) if sign-in fails.

---


### `revertDomainFederation.ps1` — return a domain to managed auth (Graph SDK)

**Dry run by default.** Removes the domain's federation config (returning it to cloud/managed authentication). Idempotent: if the domain isn't federated, it reports and exits. Optionally clears a user's immutable ID.

| Parameter | Notes |
|---|---|
| `-DomainName` | **Required.** The federated domain to revert. |
| `-ExpectedTenantId` | Recommended. Aborts on tenant mismatch. |
| `-ClearImmutableId` + `-ImmutableIdUser` | Optional, both required together, to reset one user to a cloud identity. |
| `-Execute` | **Required to make changes.** Omitted = dry run. |

```powershell
# Preview
./revertDomainFederation.ps1

# Apply
./revertDomainFederation.ps1 -Execute

# Also reset the test user to a cloud identity
./revertDomainFederation.ps1 -Execute -ClearImmutableId -ImmutableIdUser "user@<customdomain>"
```

---

### `immutableID.ps1` — set cloud-user immutable IDs (Graph SDK)

**Dry run by default.** For every cloud-only user whose UPN ends with the target domain, sets `OnPremisesImmutableId = UserPrincipalName` so Entra can match the user to authentik's SAML NameID assertion. On-premises-synchronized users are **skipped automatically** (their anchor is managed by Entra Connect and must not be overwritten). Idempotent: users already set correctly are skipped.

| Parameter | Notes |
|---|---|
| `-Domain` | **Required.** The federated domain whose users to process (e.g. `timboslice.app`). Matches on `userPrincipalName` ending in `@<Domain>`. |
| `-ExpectedTenantId` | Recommended. Aborts if the connected tenant differs. |
| `-Execute` | **Required to make changes.** Omitted = dry run. |

**How to run**

```powershell
# 1. Preview every user that would change (no writes)
./immutableID.ps1 -Domain "timboslice.app"

# 2. Apply
./immutableID.ps1 -Domain "timboslice.app" -Execute
```

**Adding a user**

There's nothing to "add" per user — the script discovers all users on the domain automatically. To bring a **new** user into the federation:

1. Create the user in Entra with a UPN on the federated domain (e.g. `newuser@timboslice.app`), or ensure they exist in authentik and sign in once.
2. Re-run the script; it will pick up the new user and set their immutable ID:
   ```powershell
   ./immutableID.ps1 -Domain "timboslice.app" -Execute
   ```
   Existing users already set are reported `OK (already set)` and skipped, so re-running is safe.

To set just **one** specific user by hand instead:

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All"
Update-MgUser -UserId "newuser@timboslice.app" -OnPremisesImmutableId "newuser@timboslice.app"
```

> **Important:** the value set here (the UPN) must **exactly match** what the authentik provider returns as its NameID property mapping, or sign-in fails for that user.
>
> - If your authentik NameID mapping returns the **UPN/email** → this script is correct as-is.
> - If it returns a **source anchor** (`mS-DS-ConsistencyGuid` / `objectGUID`, base64) → use that value instead, and do **not** run this script against Entra Connect–synced users.

**authentik ImmutableID / NameID property mapping — pick ONE return**

The authentik doc lists two expressions for this mapping. They are **alternatives**, not both. Python stops at the first `return`, so pasting both (and leaving the wrong one active) yields an **empty** NameID → `AADSTS50008`. Use exactly one:

```python
# Cloud-only users (UPN == email). This is the common case.
# For AD-synced users instead, use the source anchor:
#   return user.attributes.get("entra_immutable_id", "")
return user.email
```

The value this returns must equal the `OnPremisesImmutableId` set in Entra by `immutableID.ps1` (the UPN, for cloud-only users).

---

### `federatedID.ps1` — legacy single-file federation (Graph SDK)

An earlier, non-idempotent federation script kept for reference. It hardcodes config at the top and uses the OIDC (`/application/o/...`) endpoints with `-PreferredAuthenticationProtocol "saml"`.

> Prefer **`autoDomainFederation.ps1`** for new work — it is dry-run-safe, tenant-guarded, idempotent, and uses the documented WS-Fed endpoints.

---

## Typical dry-run → execute cycle

```powershell
# 1. Install the three Graph sub-modules (one time)
Install-Module Microsoft.Graph.Authentication,
    Microsoft.Graph.Identity.DirectoryManagement,
    Microsoft.Graph.Users -Scope CurrentUser

# 2. Dry run (no changes)
./autoDomainFederation.ps1

# 3. Review the printed tenant, account, and URIs

# 4. Apply
./autoDomainFederation.ps1 -Execute

# 5. To undo:
./revertDomainFederation.ps1 -Execute

# (If only the issuer is wrong on a live federation, fix it in place:)
./updateFederationIssuer.ps1 -Execute
```
