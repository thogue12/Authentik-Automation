#!/usr/bin/env pwsh

# Command-line parameters. Dry run by default; pass -Execute to apply.
param(
    [string]$DomainName       = "<custom domain name>",
    [string]$AuthentikHost    = "<authentikHostdomain>", #eg dsb.xyz
    [string]$Slug             = "<application slug name>",
    [string]$CertificatePath  = "$HOME/<pathTotheCertYoudownload>", #remove the $HOME if you need
    [string]$ExpectedTenantId = "<youtenantID>",
    [switch]$Force,
    [switch]$Execute
)

function Assert-GraphReady {
    [CmdletBinding()]
    param(
        [string]$ExpectedTenantId
    )

    if (-not (Get-Module -ListAvailable Microsoft.Graph.Authentication)) {
        throw "Microsoft.Graph is not installed. Install it first with: Install-Module Microsoft.Graph -Scope CurrentUser"
    }

    $context        = Get-MgContext -ErrorAction SilentlyContinue
    $requiredScopes = @("Domain.ReadWrite.All", "Directory.AccessAsUser.All")

    # Determine whether we must (re)connect: no session, wrong tenant, or missing scopes.
    $needsConnect = $false
    if (-not $context) {
        $needsConnect = $true
    }
    else {
        if ($ExpectedTenantId -and $context.TenantId -ne $ExpectedTenantId) {
            Write-Host "Active session is tenant '$($context.TenantId)', but '$ExpectedTenantId' was requested. Reconnecting..." -ForegroundColor Yellow
            $needsConnect = $true
        }
        $missing = $requiredScopes | Where-Object { $context.Scopes -notcontains $_ }
        if ($missing) {
            Write-Host "Active session is missing scopes: $($missing -join ', '). Reconnecting..." -ForegroundColor Yellow
            $needsConnect = $true
        }
    }

    if ($needsConnect) {
        Write-Host "Connecting to Microsoft Graph (interactive sign-in)..." -ForegroundColor Yellow
        $connectArgs = @{ Scopes = $requiredScopes; ErrorAction = 'Stop' }
        if ($ExpectedTenantId) { $connectArgs['TenantId'] = $ExpectedTenantId }
        Connect-MgGraph @connectArgs | Out-Null
        $context = Get-MgContext -ErrorAction Stop
    }

    if (-not $context -or [string]::IsNullOrWhiteSpace($context.TenantId)) {
        throw "ABORT: no active Microsoft Graph session after connect. Sign-in may have been cancelled. No action taken."
    }

    if ($ExpectedTenantId -and $context.TenantId -ne $ExpectedTenantId) {
        throw "ABORT: connected tenant '$($context.TenantId)' does not match -ExpectedTenantId '$ExpectedTenantId'. No action taken."
    }

    return $context
}

function Get-CleanCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw "Certificate file could not be found or is invalid at path: '$Path'"
    }

    Write-Host "Parsing certificate from: $Path" -ForegroundColor Cyan

    $rawCert = Get-Content -Path $Path -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($rawCert)) {
        throw "The certificate file at '$Path' is empty."
    }

    $cleanCert = $rawCert -replace "-----BEGIN CERTIFICATE-----", "" `
        -replace "-----END CERTIFICATE-----", "" `
        -replace "\s", ""

    if ($cleanCert.Length -lt 50) {
        throw "The parsed certificate string appears malformed or too short to be valid."
    }

    return $cleanCert
}

function Get-FederationConfigForDomain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DomainName
    )

    try {
        $configs = @(Get-MgDomainFederationConfiguration -DomainId $DomainName -ErrorAction Stop)
    }
    catch {
        return $null
    }

    if ($configs.Count -eq 0) {
        return $null
    }

    if ($configs.Count -gt 1) {
        throw "Domain '$DomainName' has $($configs.Count) federation configurations. Ambiguous state; refusing to auto-modify. Inspect and resolve manually."
    }

    return $configs[0]
}

#endregion Helpers

#region Main

function Set-EntraDomainFederation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainName,

        # authentik host FQDN only, e.g. "timboslice.dsb-hub.xyz" (no scheme/trailing slash).
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AuthentikHost,

        # The authentik application slug, e.g. "azure-entra-app".
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Slug,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CertificatePath,

        [string]$ExpectedTenantId,

        # Defaults to acceptIfMfaDoneByFederatedIdp per the M365 integration guide.
        [string]$FederatedIdpMfaBehavior = "acceptIfMfaDoneByFederatedIdp",

        [switch]$Force,
        [switch]$Execute
    )

    $mode = if ($Execute) { "EXECUTE" } else { "DRY RUN (no changes)" }
    Write-Host "=== Federate domain  [$mode] ===" -ForegroundColor Cyan

    #--- Build federation URIs from host + slug ---
    $hostClean = ($AuthentikHost.Trim() -replace '^https?://', '').TrimEnd('/')
    $base      = "https://$hostClean"
    $PassiveSignInUri    = "$base/application/wsfed/"
    $ActiveSignInUri     = "$base/application/wsfed/"
    $SignOutUri          = "$base/application/wsfed/$Slug/"
    $IssuerUri           = "$base/application/saml/$Slug/metadata/"
    $MetadataExchangeUri = "$base/application/wsfed/$Slug/metadata/"
    $DisplayName         = $DomainName



    #--- Connect / verify target ----------------------------------------------
    try {
        $context = Assert-GraphReady -ExpectedTenantId $ExpectedTenantId
    }
    catch {
        Write-Error $_
        return
    }

    Write-Host "Connected tenant : $($context.TenantId)"
    Write-Host "Signed-in account: $($context.Account)"
    Write-Host "Target domain    : $DomainName"
    Write-Host ""

    #--- Verify domain exists and is verified ---------------------------------
    try {
        $domain = Get-MgDomain -DomainId $DomainName -ErrorAction Stop
    }
    catch {
        Write-Error "Domain '$DomainName' was not found in tenant '$($context.TenantId)'. No action taken."
        return
    }

    if (-not $domain.IsVerified) {
        Write-Error "Domain '$DomainName' is not verified. Verify it in Entra ID (Custom domain names) before federating. No action taken."
        return
    }

    Write-Host "Domain is verified. Current AuthenticationType: $($domain.AuthenticationType)"

    #--- Existing config check (idempotency / replace guard) ------------------
    try {
        $existing = Get-FederationConfigForDomain -DomainName $DomainName
    }
    catch {
        Write-Error $_
        return
    }

    if ($existing -and -not $Force) {
        Write-Host "[STOP] Domain '$DomainName' already has a federation configuration (Id: $($existing.Id))." -ForegroundColor Yellow
        Write-Host "       Re-run with -Force to REPLACE it. No changes made." -ForegroundColor Yellow
        return
    }

    #--- Parse certificate (read-only) ----------------------------------------
    try {
        $certBase64 = Get-CleanCertificate -Path $CertificatePath
    }
    catch {
        Write-Error "Certificate Parsing Error: $_"
        return
    }

    #--- Preview / apply ------------------------------------------------------
    $verb = if ($existing) { "REPLACE existing federation on" } else { "FEDERATE" }

    if (-not $Execute) {
        Write-Host "[DRY RUN] Would $verb domain '$DomainName':" -ForegroundColor Yellow
        if ($existing) {
            Write-Host "[DRY RUN]   - remove existing config Id '$($existing.Id)'" -ForegroundColor Yellow
        }
        Write-Host "[DRY RUN]   - create config:" -ForegroundColor Yellow
        Write-Host "[DRY RUN]       IssuerUri           = $IssuerUri"           -ForegroundColor Yellow
        Write-Host "[DRY RUN]       PassiveSignInUri    = $PassiveSignInUri"    -ForegroundColor Yellow
        Write-Host "[DRY RUN]       ActiveSignInUri     = $ActiveSignInUri"     -ForegroundColor Yellow
        Write-Host "[DRY RUN]       SignOutUri          = $SignOutUri"          -ForegroundColor Yellow
        Write-Host "[DRY RUN]       MetadataExchangeUri = $MetadataExchangeUri" -ForegroundColor Yellow
        Write-Host "[DRY RUN]       FederatedIdpMfaBehavior = $FederatedIdpMfaBehavior" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Re-run with -Execute to apply." -ForegroundColor Yellow
        return
    }

    try {
        if ($existing) {
            Write-Host "Removing existing federation configuration (Id: $($existing.Id))..." -ForegroundColor Yellow
            Remove-MgDomainFederationConfiguration -DomainId $DomainName -InternalDomainFederationId $existing.Id -ErrorAction Stop
        }

        Write-Host "Applying WS-Federation configuration to '$DomainName'..." -ForegroundColor Cyan
        New-MgDomainFederationConfiguration -DomainId $DomainName `
            -PassiveSignInUri $PassiveSignInUri `
            -ActiveSignInUri $ActiveSignInUri `
            -SignOutUri $SignOutUri `
            -IssuerUri $IssuerUri `
            -MetadataExchangeUri $MetadataExchangeUri `
            -SigningCertificate $certBase64 `
            -DisplayName $DisplayName `
            -FederatedIdpMfaBehavior $FederatedIdpMfaBehavior `
            -PreferredAuthenticationProtocol "wsFed" -ErrorAction Stop | Out-Null

        Write-Host "`n[SUCCESS] Domain '$DomainName' is now federated." -ForegroundColor Green
        Get-MgDomain -DomainId $DomainName | Select-Object Id, AuthenticationType, IsVerified

        Write-Host "`n[ROLLBACK] To revert this domain to managed (cloud) authentication:" -ForegroundColor Cyan
        Write-Host "  Use revertDomainFederation.ps1, or:" -ForegroundColor Cyan
        Write-Host "  `$fed = Get-MgDomainFederationConfiguration -DomainId '$DomainName'" -ForegroundColor Cyan
        Write-Host "  Remove-MgDomainFederationConfiguration -DomainId '$DomainName' -InternalDomainFederationId `$fed.Id" -ForegroundColor Cyan
    }
    catch {
        Write-Error "API Execution Error: Failed to apply federation settings for domain '$DomainName'."
        Write-Error "Details: $_"
        Write-Host "`n[TROUBLESHOOTING TIPS]:" -ForegroundColor Yellow
        Write-Host "  1. Ensure '$DomainName' is fully verified in Entra ID (Custom domain names)." -ForegroundColor Yellow
        Write-Host "  2. Verify your authentik endpoints and signing certificate are correct."       -ForegroundColor Yellow
        Write-Host "  3. Ensure your account holds Global Administrator or Domain Name Administrator." -ForegroundColor Yellow
        Write-Host "  4. Recover using your break-glass admin on a non-federated domain if sign-in breaks." -ForegroundColor Yellow
    }
}

#endregion Main

#region Execution  (runs only when invoked directly, never when dot-sourced)

if ($MyInvocation.InvocationName -ne '.') {

    if ([string]::IsNullOrWhiteSpace($DomainName)) {
        Write-Host "Provide -DomainName (your verified domain). No action taken." -ForegroundColor Yellow
        return
    }

    $params = @{
        DomainName      = $DomainName
        AuthentikHost   = $AuthentikHost
        Slug            = $Slug
        CertificatePath = $CertificatePath
        Force           = $Force
        Execute         = $Execute
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedTenantId)) {
        $params['ExpectedTenantId'] = $ExpectedTenantId
    }

    Set-EntraDomainFederation @params
}

#endregion Execution
