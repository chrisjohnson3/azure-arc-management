<#
.SYNOPSIS
    Enable Azure Benefits for all Arc-enabled Windows Servers in subscription

.DESCRIPTION
    This script enables the "Activate Azure benefits" checkbox for all Arc-enabled Windows Servers
    in the current subscription. Includes option to exclude specific machines.

.PREREQUISITES
    Run these commands ONCE before using this script:
    1. Install-Module Az.Accounts -Force -Scope CurrentUser
    2. Install-Module Az.Resources -Force -Scope CurrentUser
    3. Connect-AzAccount
    4. Set-AzContext -SubscriptionId "your-subscription-id"

.PARAMETER ExcludeMachines
    Array of machine names to skip (optional)

.EXAMPLE
    .\Enable-AzureArcSABenefits-All.ps1

.EXAMPLE
    .\Enable-AzureArcSABenefits-All.ps1 -ExcludeMachines "dev-server","test-vm"
#>

param(
    [Parameter(Mandatory=$false)]
    [string[]]$ExcludeMachines
)

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Arc Windows Server - Azure Benefits (All)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$context = Get-AzContext
if (-not $context) {
    Write-Host "✗ Not connected to Azure. Run 'Connect-AzAccount' first.`n" -ForegroundColor Red
    exit 1
}

Write-Host "Subscription: $($context.Subscription.Name)" -ForegroundColor Yellow
Write-Host "Searching for Arc Windows Servers...`n" -ForegroundColor Yellow

# Get all Arc machines in subscription
$allServers = Get-AzResource -ResourceType 'Microsoft.HybridCompute/machines'

if ($allServers.Count -eq 0) {
    Write-Host "✗ No Arc machines found in subscription`n" -ForegroundColor Red
    exit 1
}

# Filter to Windows machines
$windowsServers = $allServers | Where-Object {
    $detail = Get-AzResource -ResourceId $_.ResourceId
    $detail.Properties.osName -like "*Windows*"
}

if ($windowsServers.Count -eq 0) {
    Write-Host "✗ No Windows Server machines found`n" -ForegroundColor Red
    exit 1
}

# Apply exclusions
if ($ExcludeMachines -and $ExcludeMachines.Count -gt 0) {
    Write-Host "Excluding machines: $($ExcludeMachines -join ', ')" -ForegroundColor Yellow
    $windowsServers = $windowsServers | Where-Object { $_.Name -notin $ExcludeMachines }
    
    if ($windowsServers.Count -eq 0) {
        Write-Host "✗ No machines left after exclusions`n" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Found $($windowsServers.Count) Windows Server machine(s)`n" -ForegroundColor Green

# Safety confirmation
Write-Host "WARNING: This will modify $($windowsServers.Count) machine(s) across your subscription" -ForegroundColor Yellow
$confirm = Read-Host "Type 'YES' to continue or anything else to cancel"
if ($confirm -ne 'YES') {
    Write-Host "`nOperation cancelled`n" -ForegroundColor Yellow
    exit 0
}

Write-Host "`n========================================" -ForegroundColor Gray
Write-Host "Processing Machines" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Gray

$api = '2023-10-03-preview'
$results = @()
$counter = 0

foreach ($server in $windowsServers) {
    $counter++
    $serverName = $server.Name
    $rg = $server.ResourceGroupName
    $profilePath = $server.ResourceId + '/licenseProfiles/default'
    
    Write-Host "[$counter/$($windowsServers.Count)] $serverName" -ForegroundColor Cyan
    Write-Host "  Resource Group: $rg" -ForegroundColor Gray
    
    # Check current status
    try {
        $existingProfile = Get-AzResource -ResourceId $profilePath -ApiVersion $api -ErrorAction SilentlyContinue
        $isEnabled = $existingProfile.Properties.softwareAssurance.softwareAssuranceCustomer
        Write-Host "  Current Status: $isEnabled" -ForegroundColor Gray
        
        if ($isEnabled -eq $true) {
            Write-Host "  Result: Already enabled ✓`n" -ForegroundColor Green
            $results += [PSCustomObject]@{
                Machine = $serverName
                ResourceGroup = $rg
                Action = "No change"
                Result = "Already enabled"
            }
            continue
        }
    } catch {
        Write-Host "  Current Status: Not configured" -ForegroundColor Gray
    }
    
    # Enable Azure benefits
    Write-Host "  Enabling..." -ForegroundColor Yellow
    
    $licenseConfig = @{
        softwareAssurance = @{
            softwareAssuranceCustomer = $true
        }
    }
    
    try {
        $result = New-AzResource -ResourceId $profilePath -Properties $licenseConfig -Location $server.Location -ApiVersion $api -Force
        
        Write-Host "  Result: SUCCESS ✓`n" -ForegroundColor Green
        $results += [PSCustomObject]@{
            Machine = $serverName
            ResourceGroup = $rg
            Action = "Enabled"
            Result = "Success"
        }
    } catch {
        Write-Host "  Result: FAILED ✗" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)`n" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Machine = $serverName
            ResourceGroup = $rg
            Action = "Failed"
            Result = $_.Exception.Message
        }
    }
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$results | Format-Table -AutoSize

$total = $results.Count
$alreadyEnabled = ($results | Where-Object {$_.Action -eq 'No change'}).Count
$newlyEnabled = ($results | Where-Object {$_.Action -eq 'Enabled'}).Count
$failed = ($results | Where-Object {$_.Action -eq 'Failed'}).Count

Write-Host "Total machines: $total" -ForegroundColor White
Write-Host "Already enabled: $alreadyEnabled" -ForegroundColor Green
Write-Host "Newly enabled: $newlyEnabled" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "Failed: $failed" -ForegroundColor Red
}

Write-Host "`n========================================`n" -ForegroundColor Cyan
