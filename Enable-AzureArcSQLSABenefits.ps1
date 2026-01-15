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
    .\Enable-AzureArcSQLSABenefits.ps1 -ResourceGroupName "rg-arc" -MachineName "sql-server-01" -LicenseType "Paid"
#>
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

Write-Host "`nUpdating SQL Server license type" -ForegroundColor Cyan
Write-Host "Machine: $MachineName (rg: $ResourceGroupName)" -ForegroundColor Gray
Write-Host "Target: $LicenseType`n" -ForegroundColor Gray

# Get the SQL Server extension
Write-Host "Checking for SQL Server extension..." -ForegroundColor Yellow
$extension = Get-AzConnectedMachineExtension -ResourceGroupName $ResourceGroupName -MachineName $MachineName -Name "WindowsAgent.SqlServer" -ErrorAction SilentlyContinue

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

# Update settings
Write-Host "Updating license type..." -ForegroundColor Yellow

if (-not $currentSettings.ContainsKey("SqlManagement")) {
    $currentSettings["SqlManagement"] = @{ IsEnabled = $true }
}
$currentSettings["LicenseType"] = $LicenseType

try {
    Update-AzConnectedMachineExtension -ResourceGroupName $ResourceGroupName -MachineName $MachineName -Name "WindowsAgent.SqlServer" -Setting $currentSettings | Out-Null
    Write-Host "Updated`n" -ForegroundColor Green
    
    $updatedExtension = Get-AzConnectedMachineExtension -ResourceGroupName $ResourceGroupName -MachineName $MachineName -Name "WindowsAgent.SqlServer"
    $verifiedType = $updatedExtension.Setting["LicenseType"]
    
    if ($verifiedType -ne $LicenseType) {
        Write-Host "Warning: Verification shows $verifiedType`n" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Failed: $($_.Exception.Message)`n" -ForegroundColor Red
    exit 1
}