
# Command-line parameters. Dry run by default; pass -Execute to apply.
param(
    [string]$DomainName       = "<customDomain>",
    [string]$ExpectedTenantId = "<yourTenantID>",
    [switch]$ClearImmutableId,
    [string]$ImmutableIdUser,
    [switch]$Execute
)

#region Helpers

function Assert-GraphReady {
    [CmdletBinding()]
    param(
        [string]$ExpectedTenantId
    )

    if (-not (Get-Module -ListAvailable Microsoft.Graph.Authentication)) {
        throw "Microsoft.Graph is not installed. Install it first with: Install-Module Microsoft.Graph -Scope CurrentUser"
    }

    $context        = Get-MgContext -ErrorAction SilentlyContinue
    $requiredScopes = @("Domain.ReadWrite.All", "Directory.AccessAsUser.All", "User.ReadWrite.All")

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
        throw "Domain '$DomainName' has $($configs.Count) federation configurations. Ambiguous state; refusing to auto-delete. Inspect and remove manually."
    }

    return $configs[0]
}

function Reset-UserImmutableId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [switch]$Execute
    )

    try {
        $user = Get-MgUser -UserId $UserId -Property "id,userPrincipalName,onPremisesImmutableId" -ErrorAction Stop
    }
    catch {
        Write-Error "Could not find user '$UserId': $_"
        return
    }

    if ([string]::IsNullOrWhiteSpace($user.OnPremisesImmutableId)) {
        Write-Host "[OK] User '$UserId' has no OnPremisesImmutableId. Nothing to clear." -ForegroundColor Green
        return
    }

    if (-not $Execute) {
        Write-Host "[DRY RUN] Would clear OnPremisesImmutableId ('$($user.OnPremisesImmutableId)') on user '$UserId'." -ForegroundColor Yellow
        return
    }

    try {
        Update-MgUser -UserId $UserId -OnPremisesImmutableId $null -ErrorAction Stop
        Write-Host "[SUCCESS] Cleared OnPremisesImmutableId for '$UserId'." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to clear OnPremisesImmutableId for '$UserId': $_"
    }
}

#endregion Helpers

#region Main

function Restore-EntraDomainToManaged {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainName,

        [string]$ExpectedTenantId,

        [switch]$ClearImmutableId,
        [string]$ImmutableIdUser,

        [switch]$Execute
    )

    $mode = if ($Execute) { "EXECUTE" } else { "DRY RUN (no changes)" }
    Write-Host "=== Revert domain federation  [$mode] ===" -ForegroundColor Cyan

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

    #--- Verify the domain exists in THIS tenant ------------------------------
    try {
        $domain = Get-MgDomain -DomainId $DomainName -ErrorAction Stop
    }
    catch {
        Write-Error "Domain '$DomainName' was not found in tenant '$($context.TenantId)'. No action taken."
        return
    }

    Write-Host "Domain current AuthenticationType: $($domain.AuthenticationType)"

    #--- Resolve federation config (idempotent short-circuit) -----------------
    try {
        $fed = Get-FederationConfigForDomain -DomainName $DomainName
    }
    catch {
        Write-Error $_
        return
    }

    if (-not $fed) {
        Write-Host "[OK] Domain '$DomainName' has no federation configuration. Already managed; nothing to revert." -ForegroundColor Green
    }
    else {
        if ($fed.PSObject.Properties.Name -contains 'IssuerUri') {
            Write-Host "Found federation config (Id: $($fed.Id), Issuer: $($fed.IssuerUri))."
        }
        else {
            Write-Host "Found federation config (Id: $($fed.Id))."
        }

        if (-not $Execute) {
            Write-Host "[DRY RUN] Would remove federation config Id '$($fed.Id)' from domain '$DomainName'." -ForegroundColor Yellow
            Write-Host "[DRY RUN] Re-run with -Execute to apply." -ForegroundColor Yellow
        }
        else {
            try {
                Remove-MgDomainFederationConfiguration `
                    -DomainId $DomainName `
                    -InternalDomainFederationId $fed.Id `
                    -ErrorAction Stop
                Write-Host "[SUCCESS] Removed federation config. '$DomainName' is reverting to managed authentication." -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to remove federation configuration for '$DomainName': $_"
                Write-Host "If sign-in is affected, recover with a break-glass admin on a non-federated domain." -ForegroundColor Yellow
                return
            }
        }
    }

    #--- Optional, explicitly-gated identity reset ----------------------------
    if ($ClearImmutableId) {
        if ([string]::IsNullOrWhiteSpace($ImmutableIdUser)) {
            Write-Error "-ClearImmutableId was specified without -ImmutableIdUser. Skipping identity change for safety."
        }
        else {
            Reset-UserImmutableId -UserId $ImmutableIdUser -Execute:$Execute
        }
    }

    Write-Host "`nFinal domain status:" -ForegroundColor Cyan
    Get-MgDomain -DomainId $DomainName | Select-Object Id, AuthenticationType, IsVerified
}

#endregion Main

#region Execution  (runs only when invoked directly, never when dot-sourced)

if ($MyInvocation.InvocationName -ne '.') {

    if ([string]::IsNullOrWhiteSpace($DomainName)) {
        Write-Host "Provide -DomainName (the domain to revert). No action taken." -ForegroundColor Yellow
        return
    }

    $params = @{
        DomainName       = $DomainName
        ClearImmutableId = $ClearImmutableId
        Execute          = $Execute
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedTenantId)) {
        $params['ExpectedTenantId'] = $ExpectedTenantId
    }
    if (-not [string]::IsNullOrWhiteSpace($ImmutableIdUser)) {
        $params['ImmutableIdUser'] = $ImmutableIdUser
    }

    Restore-EntraDomainToManaged @params
}

#endregion Execution
