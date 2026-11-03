#Requires -Version 7.0
<#
.SYNOPSIS
    Update SQL Server license type for all Arc servers in a subscription

.PARAMETER LicenseType
    License type: PAYG, Paid, or LicenseOnly

.EXAMPLE
    .\Update-ArcSQLLicenseType-All.ps1 -LicenseType "Paid"
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
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
$subscriptionName = $context.Subscription.Name
$subscriptionId = $context.Subscription.Id

Write-Host "`nUpdating SQL Server license type in subscription" -ForegroundColor Cyan
Write-Host "Subscription: $subscriptionName ($subscriptionId)" -ForegroundColor Gray
Write-Host "Target: $LicenseType`n" -ForegroundColor Gray

# Get all resource groups
Write-Host "Scanning subscription for Arc SQL servers..." -ForegroundColor Gray

$resourceGroups = Get-AzResourceGroup -ErrorAction Stop
$sqlMachines = @()

foreach ($rg in $resourceGroups) {
    $machines = Get-AzConnectedMachine -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop
    
    if ($machines) {
        foreach ($machine in $machines) {
            $extensions = Get-AzConnectedMachineExtension -ResourceGroupName $rg.ResourceGroupName -MachineName $machine.Name -ErrorAction Stop
            $sqlExt = $extensions | Where-Object { $_.Name -eq "WindowsAgent.SqlServer" }
            
            if ($sqlExt) {
                $sqlMachines += [PSCustomObject]@{
                    MachineName       = $machine.Name
                    ResourceGroupName = $rg.ResourceGroupName
                }
            }
        }
    }
}

if ($sqlMachines.Count -eq 0) {
    Write-Host "No Arc machines with SQL Server extension found`n" -ForegroundColor Red
    exit 1
}

# Group by resource group for display
$groupedMachines = $sqlMachines | Group-Object -Property ResourceGroupName

Write-Host "Found $($sqlMachines.Count) machine(s) across $($groupedMachines.Count) resource group(s)`n" -ForegroundColor Gray

$sqlMachines | Format-Table MachineName, ResourceGroupName -AutoSize | Out-Host
Write-Warning "Confirm the selected license type matches your SQL Server entitlement. PAYG can start Azure billing; Paid declares active SA/subscription coverage. Changing license type does not verify entitlement."
if (-not $PSCmdlet.ShouldProcess("$($sqlMachines.Count) Windows SQL machines in subscription $subscriptionId", "Set SQL Server license type to $LicenseType")) {
    exit 0
}
Write-Host ""

# Process each machine
$successCount = 0
$failCount = 0
$skipCount = 0
$processed = 0

foreach ($group in $groupedMachines) {
    Write-Host "Resource Group: $($group.Name)" -ForegroundColor Cyan
    
    foreach ($machine in $group.Group) {
        $processed++
        Write-Host "  [$processed/$($sqlMachines.Count)] $($machine.MachineName)" -ForegroundColor Gray
        
        try {
            # Get current extension settings
            $extension = Get-AzConnectedMachineExtension -ResourceGroupName $machine.ResourceGroupName -MachineName $machine.MachineName -Name "WindowsAgent.SqlServer" -ErrorAction Stop
            
            $currentSettings = @{}
            if ($extension.Setting) {
                $currentSettings = $extension.Setting | ConvertTo-Json -Depth 10 | ConvertFrom-Json -AsHashtable
            }
            
            $currentLicenseType = $currentSettings["LicenseType"]
            
            if ($currentLicenseType -eq $LicenseType) {
                Write-Host "    Already set to $LicenseType`n" -ForegroundColor Green
                $skipCount++
                continue
            }
            
            Write-Host "    Updating to $LicenseType" -ForegroundColor Yellow
            
            # Update settings
            if (-not $currentSettings.ContainsKey("SqlManagement")) {
                $currentSettings["SqlManagement"] = @{ IsEnabled = $true }
            }
            $currentSettings["LicenseType"] = $LicenseType
            
            Update-AzConnectedMachineExtension -ResourceGroupName $machine.ResourceGroupName -MachineName $machine.MachineName -Name "WindowsAgent.SqlServer" -Setting $currentSettings -ErrorAction Stop | Out-Null
            Assert-ArcSQLLicenseType -ResourceGroupName $machine.ResourceGroupName -MachineName $machine.MachineName -LicenseType $LicenseType
            Write-Host "    Done`n" -ForegroundColor Green
            $successCount++
            
        } catch {
            Write-Host "    Failed: $($_.Exception.Message)`n" -ForegroundColor Red
            $failCount++
        }
    }
    Write-Host ""
}

# Summary
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Total: $($sqlMachines.Count) | Updated: $successCount" -ForegroundColor White
if ($skipCount -gt 0) {
    Write-Host "Skipped: $skipCount" -ForegroundColor Gray
}
if ($failCount -gt 0) {
    Write-Host "Failed: $failCount" -ForegroundColor Red
    exit 1
}

Write-Host ""
exit 0