#Requires -Version 7.0
<#
.SYNOPSIS
    Update SQL Server license type for an Arc server

.PARAMETER ResourceGroupName
    Resource group name

.PARAMETER MachineName
    Arc server name

.PARAMETER LicenseType
    License type: PAYG, Paid, or LicenseOnly

.EXAMPLE
    .\Update-ArcSQLLicenseType-Single.ps1 -ResourceGroupName "rg-arc" -MachineName "sql-server-01" -LicenseType "Paid"
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$MachineName,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("PAYG", "Paid", "LicenseOnly")]
    [string]$LicenseType
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\ArcManagement.Helpers.ps1"

$context = Get-AzContext
if (-not $context) {
    Write-Host "Not connected to Azure. Run 'Connect-AzAccount' first." -ForegroundColor Red
    exit 1
}

Write-Host "`nUpdating SQL Server license type" -ForegroundColor Cyan
Write-Host "Machine: $MachineName (rg: $ResourceGroupName)" -ForegroundColor Gray
Write-Host "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -ForegroundColor Gray
Write-Host "Target: $LicenseType`n" -ForegroundColor Gray

# Get the SQL Server extension
Write-Host "Checking for SQL Server extension..." -ForegroundColor Yellow
$extension = Get-AzConnectedMachineExtension -ResourceGroupName $ResourceGroupName -MachineName $MachineName -Name "WindowsAgent.SqlServer" -ErrorAction Stop

if (-not $extension) {
    Write-Host "✗ SQL Server extension not found on this machine`n" -ForegroundColor Red
    exit 1
}

# Get current settings
$currentSettings = @{}
if ($extension.Setting) {
    $currentSettings = $extension.Setting | ConvertTo-Json -Depth 10 | ConvertFrom-Json -AsHashtable
}

$currentLicenseType = $currentSettings["LicenseType"]

if ($currentLicenseType -eq $LicenseType) {
    Write-Host "Already set to $LicenseType`n" -ForegroundColor Green
    exit 0
}

Write-Warning "Confirm the selected license type matches your SQL Server entitlement. PAYG can start Azure billing; Paid declares active SA/subscription coverage. Changing license type does not verify entitlement."
if (-not $PSCmdlet.ShouldProcess("$ResourceGroupName/$MachineName in subscription $($context.Subscription.Id)", "Set SQL Server license type to $LicenseType")) {
    exit 0
}
Write-Host "Updating license type..." -ForegroundColor Yellow

if (-not $currentSettings.ContainsKey("SqlManagement")) {
    $currentSettings["SqlManagement"] = @{ IsEnabled = $true }
}
$currentSettings["LicenseType"] = $LicenseType

try {
    Update-AzConnectedMachineExtension -ResourceGroupName $ResourceGroupName -MachineName $MachineName -Name "WindowsAgent.SqlServer" -Setting $currentSettings -ErrorAction Stop | Out-Null
    Assert-ArcSQLLicenseType -ResourceGroupName $ResourceGroupName -MachineName $MachineName -LicenseType $LicenseType
    Write-Host "Updated`n" -ForegroundColor Green
} catch {
    Write-Host "Failed: $($_.Exception.Message)`n" -ForegroundColor Red
    exit 1
}
exit 0