

param(
    [string]$Domain           = "<customDomain>",
    [string]$ExpectedTenantId = "<yourTenantID>",
    [switch]$Execute
)

function Assert-GraphReady {
    [CmdletBinding()]
    param([string]$ExpectedTenantId)

    if (-not (Get-Module -ListAvailable Microsoft.Graph.Authentication)) {
        throw "Microsoft.Graph is not installed. Install it first with: Install-Module Microsoft.Graph -Scope CurrentUser"
    }

    $context        = Get-MgContext -ErrorAction SilentlyContinue
    $requiredScopes = @("User.ReadWrite.All")

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

function Set-CloudUserImmutableIds {
    param(
        [Parameter(Mandatory = $true)][string]$Domain,
        [string]$ExpectedTenantId,
        [switch]$Execute
    )

    $mode = if ($Execute) { "EXECUTE" } else { "DRY RUN (no changes)" }
    Write-Host "=== Set cloud-user immutable IDs for '@$Domain'  [$mode] ===" -ForegroundColor Cyan

    try {
        $context = Assert-GraphReady -ExpectedTenantId $ExpectedTenantId
    }
    catch {
        Write-Error $_
        return
    }

    Write-Host "Connected tenant : $($context.TenantId)"
    Write-Host "Signed-in account: $($context.Account)"
    Write-Host "Target domain    : @$Domain"
    Write-Host ""

    # endsWith(...) requires advanced query params: -ConsistencyLevel eventual + -CountVariable.
    try {
        $users = Get-MgUser -All `
            -Filter "endsWith(userPrincipalName,'@$Domain')" `
            -ConsistencyLevel eventual `
            -CountVariable userCount `
            -Property Id, UserPrincipalName, OnPremisesSyncEnabled, OnPremisesImmutableId `
            -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to query users for domain '@$Domain': $_"
        return
    }

    if (-not $users -or @($users).Count -eq 0) {
        Write-Host "No users found with UPN ending '@$Domain'. Nothing to do." -ForegroundColor Yellow
        return
    }

    $set = 0; $skipped = 0; $already = 0
    foreach ($user in $users) {
        $upn = $user.UserPrincipalName

        if ([string]::IsNullOrWhiteSpace($upn)) {
            continue
        }

        if ($user.OnPremisesSyncEnabled -eq $true) {
            Write-Host "  SKIP (on-prem synced): $upn" -ForegroundColor DarkYellow
            $skipped++
            continue
        }

        if ($user.OnPremisesImmutableId -eq $upn) {
            Write-Host "  OK (already set):      $upn" -ForegroundColor DarkGreen
            $already++
            continue
        }

        if (-not $Execute) {
            Write-Host "  [DRY RUN] would set:   $upn  ->  OnPremisesImmutableId = $upn" -ForegroundColor Yellow
            continue
        }

        try {
            Update-MgUser -UserId $user.Id -OnPremisesImmutableId $upn -ErrorAction Stop
            Write-Host "  SET:                   $upn" -ForegroundColor Green
            $set++
        }
        catch {
            Write-Error "  FAILED: $upn - $_"
        }
    }

    Write-Host ""
    if ($Execute) {
        Write-Host "Done. Set: $set | already correct: $already | skipped (on-prem): $skipped" -ForegroundColor Cyan
    }
    else {
        Write-Host "Dry run complete. Re-run with -Execute to apply. (already correct: $already | skipped on-prem: $skipped)" -ForegroundColor Cyan
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if ([string]::IsNullOrWhiteSpace($Domain)) {
        Write-Host "Provide -Domain (e.g. 'timboslice.app'). No action taken." -ForegroundColor Yellow
        return
    }

    $params = @{
        Domain  = $Domain
        Execute = $Execute
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedTenantId)) {
        $params['ExpectedTenantId'] = $ExpectedTenantId
    }

    Set-CloudUserImmutableIds @params
}
