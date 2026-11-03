#Requires -Version 7.0
<#
.SYNOPSIS
    Enable Azure benefits for all Arc servers in a resource group

.PARAMETER ResourceGroupName
    Resource group name

.PARAMETER ExcludeMachines
    Optional list of machine names to skip

.EXAMPLE
    .\Enable-AzureArcSABenefits-ResourceGroup.ps1 -ResourceGroupName "my-rg"

.EXAMPLE
    .\Enable-AzureArcSABenefits-ResourceGroup.ps1 -ResourceGroupName "my-rg" -ExcludeMachines "dev-server","test-vm"
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string[]]$ExcludeMachines
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\ArcManagement.Helpers.ps1"

Write-Host "`nEnabling Azure benefits for Arc servers in resource group..." -ForegroundColor Cyan

$context = Get-AzContext
if (-not $context) {
    Write-Host "✗ Not connected to Azure. Run 'Connect-AzAccount' first.`n" -ForegroundColor Red
    exit 1
}

Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Gray
Write-Host "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -ForegroundColor Gray
Write-Host "Looking for Arc Windows servers..." -ForegroundColor Gray

# Get all Arc machines in resource group
$allServers = @(Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.HybridCompute/machines' -ErrorAction Stop)

if (-not $allServers -or $allServers.Count -eq 0) {
    Write-Host "No Arc machines found`n" -ForegroundColor Red
    exit 1
}

# Filter to Windows machines
$windowsServers = @($allServers | Where-Object {
    $detail = Get-AzResource -ResourceId $_.ResourceId -ExpandProperties -ErrorAction Stop
    $detail.Properties.osName -like "*Windows*"
})

if ($windowsServers.Count -eq 0) {
    Write-Host "No Windows servers found`n" -ForegroundColor Red
    exit 1
}

# Apply exclusions
if ($ExcludeMachines -and $ExcludeMachines.Count -gt 0) {
    Write-Host "Excluding machines: $($ExcludeMachines -join ', ')" -ForegroundColor Yellow
    $windowsServers = @($windowsServers | Where-Object { $_.Name -notin $ExcludeMachines })
    
    if ($windowsServers.Count -eq 0) {
        Write-Host "No machines left after exclusions`n" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Found $($windowsServers.Count) server(s)`n" -ForegroundColor Gray

$windowsServers | Select-Object Name, ResourceGroupName | Format-Table -AutoSize | Out-Host
Write-Warning "Only proceed for Windows Server machines with confirmed active Software Assurance or qualifying subscription coverage. This records your licensing declaration; it does not verify entitlement."
if (-not $PSCmdlet.ShouldProcess("$($windowsServers.Count) Windows machines in $ResourceGroupName, subscription $($context.Subscription.Id)", "Attest licensing eligibility and enable Azure benefits")) {
    exit 0
}

Write-Host ""

$api = '2023-10-03-preview'
$results = @()
$counter = 0

foreach ($server in $windowsServers) {
    $counter++
    $serverName = $server.Name
    $rg = $server.ResourceGroupName
    $profilePath = $server.ResourceId + '/licenseProfiles/default'
    
    Write-Host "[$counter/$($windowsServers.Count)] $serverName (rg: $rg)" -ForegroundColor Cyan
    
    try {
        $existingProfile = Get-ArcLicenseProfile -ResourceId $profilePath -ApiVersion $api
        $isEnabled = $existingProfile.Properties.softwareAssurance.softwareAssuranceCustomer
        
        if ($isEnabled -eq $true) {
            Write-Host "  Already enabled`n" -ForegroundColor Green
            $results += [PSCustomObject]@{
                Machine = $serverName
                ResourceGroup = $rg
                Action = "No change"
                Result = "Already enabled"
            }
            continue
        }
        Write-Host "  Enabling..." -ForegroundColor Yellow

        $licenseConfig = @{
            softwareAssurance = @{
                softwareAssuranceCustomer = $true
            }
        }

        New-AzResource -ResourceId $profilePath -Properties $licenseConfig -Location $server.Location -ApiVersion $api -Force -ErrorAction Stop | Out-Null
        Assert-ArcBenefitsEnabled -ResourceId $profilePath -ApiVersion $api
        
        Write-Host "  Done`n" -ForegroundColor Green
        $results += [PSCustomObject]@{
            Machine = $serverName
            ResourceGroup = $rg
            Action = "Enabled"
            Result = "Success"
        }
    } catch {
        Write-Host "  Failed: $($_.Exception.Message)`n" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Machine = $serverName
            ResourceGroup = $rg
            Action = "Failed"
            Result = $_.Exception.Message
        }
    }
}

# Summary
Write-Host "`nSummary:" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$total = $results.Count
$alreadyEnabled = ($results | Where-Object {$_.Action -eq 'No change'}).Count
$newlyEnabled = ($results | Where-Object {$_.Action -eq 'Enabled'}).Count
$failed = ($results | Where-Object {$_.Action -eq 'Failed'}).Count

Write-Host "`nTotal: $total | Enabled: $newlyEnabled" -ForegroundColor White
if ($alreadyEnabled -gt 0) {
    Write-Host "Already enabled: $alreadyEnabled" -ForegroundColor Gray
}
if ($failed -gt 0) {
    Write-Host "Failed: $failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
exit 0
