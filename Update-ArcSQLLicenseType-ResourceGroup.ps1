<#
.SYNOPSIS
    Update SQL Server license type for Arc servers in a resource group

.PARAMETER ResourceGroupName
    Resource group name

.PARAMETER LicenseType
    License type: PAYG, Paid, or LicenseOnly

.EXAMPLE
    .\Update-ArcSQLLicenseType-ResourceGroup.ps1 -ResourceGroupName "my-rg" -LicenseType "Paid"
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("PAYG", "Paid", "LicenseOnly")]
    [string]$LicenseType
)

$ErrorActionPreference = "Stop"

Write-Host "`nUpdating SQL Server license type in resource group" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Gray
Write-Host "Target: $LicenseType`n" -ForegroundColor Gray

# Get all Arc machines in the resource group
Write-Host "Finding Arc-enabled machines..." -ForegroundColor Yellow
$machines = Get-AzConnectedMachine -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

if (-not $machines -or $machines.Count -eq 0) {
    Write-Host "No Arc machines found`n" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($machines.Count) machine(s)`n" -ForegroundColor Gray

# Find machines with SQL Server extension
Write-Host "Checking for SQL Server extensions..." -ForegroundColor Yellow
$sqlMachines = @()

foreach ($machine in $machines) {
    $extensions = Get-AzConnectedMachineExtension -ResourceGroupName $ResourceGroupName -MachineName $machine.Name -ErrorAction SilentlyContinue
    $sqlExt = $extensions | Where-Object { $_.Name -eq "WindowsAgent.SqlServer" }
    
    if ($sqlExt) {
        $sqlMachines += $machine
        Write-Host "  Found: $($machine.Name)" -ForegroundColor Gray
    }
}

if ($sqlMachines.Count -eq 0) {
    Write-Host "No machines with SQL Server extension found`n" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Process each machine
$successCount = 0
$failCount = 0
$skipCount = 0

foreach ($machine in $sqlMachines) {
    Write-Host "[$($successCount + $failCount + $skipCount + 1)/$($sqlMachines.Count)] $($machine.Name)" -ForegroundColor Cyan
    
    try {
        # Get current extension settings
        $extension = Get-AzConnectedMachineExtension -ResourceGroupName $ResourceGroupName -MachineName $machine.Name -Name "WindowsAgent.SqlServer"
        
        $currentSettings = @{}
        if ($extension.Setting) {
            $currentSettings = $extension.Setting | ConvertTo-Json -Depth 10 | ConvertFrom-Json -AsHashtable
        }
        
        $currentLicenseType = $currentSettings["LicenseType"]
        
        if ($currentLicenseType -eq $LicenseType) {
            Write-Host "  Already set to $LicenseType`n" -ForegroundColor Green
            $skipCount++
            continue
        }
        
        Write-Host "  Updating to $LicenseType" -ForegroundColor Yellow
        
        # Update settings
        if (-not $currentSettings.ContainsKey("SqlManagement")) {
            $currentSettings["SqlManagement"] = @{ IsEnabled = $true }
        }
        $currentSettings["LicenseType"] = $LicenseType
        
        Update-AzConnectedMachineExtension -ResourceGroupName $ResourceGroupName -MachineName $machine.Name -Name "WindowsAgent.SqlServer" -Setting $currentSettings | Out-Null
        Write-Host "  Done`n" -ForegroundColor Green
        $successCount++
        
    } catch {
        Write-Host "  Failed: $($_.Exception.Message)`n" -ForegroundColor Red
        $failCount++
    }
}

# Summary
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Total: $($sqlMachines.Count) | Updated: $successCount" -ForegroundColor White
if ($skipCount -gt 0) {
    Write-Host "Skipped: $skipCount" -ForegroundColor Gray
}
if ($failCount -gt 0) {
    Write-Host "Failed: $failCount" -ForegroundColor Red
}

Write-Host ""