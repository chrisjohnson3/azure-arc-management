#Requires -Version 7.0
<#
.SYNOPSIS
    Enable Azure benefits for an Arc server

.PARAMETER ResourceGroupName
    Resource group name

.PARAMETER MachineName
    Arc server name

.EXAMPLE
    .\Enable-AzureArcSABenefits-Single.ps1 -ResourceGroupName "my-rg" -MachineName "server-01"
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$MachineName
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\ArcManagement.Helpers.ps1"

$context = Get-AzContext
if (-not $context) {
    Write-Host "Not connected to Azure. Run 'Connect-AzAccount' first." -ForegroundColor Red
    exit 1
}

Write-Host "`nEnabling Azure benefits for Arc server" -ForegroundColor Cyan
Write-Host "Machine: $MachineName (rg: $ResourceGroupName)`n" -ForegroundColor Gray
Write-Host "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -ForegroundColor Gray

# Get the Arc server resource
$arcServer = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $MachineName -ResourceType 'Microsoft.HybridCompute/machines' -ExpandProperties -ErrorAction Stop

if (-not $arcServer) {
    Write-Host "Machine not found`n" -ForegroundColor Red
    exit 1
}

if ($arcServer.Properties.osName -notlike "*Windows*") {
    Write-Host "The selected machine is not a Windows machine." -ForegroundColor Red
    exit 1
}

$profilePath = $arcServer.ResourceId + '/licenseProfiles/default'
$api = '2023-10-03-preview'

Write-Warning "Only proceed for a Windows Server machine with confirmed active Software Assurance or qualifying subscription coverage. This records your licensing declaration; it does not verify entitlement."

try {
    $existingProfile = Get-ArcLicenseProfile -ResourceId $profilePath -ApiVersion $api
    $isEnabled = $existingProfile.Properties.softwareAssurance.softwareAssuranceCustomer
    
    if ($isEnabled -eq $true) {
        Write-Host "Already enabled`n" -ForegroundColor Green
        exit 0
    }
    if (-not $PSCmdlet.ShouldProcess($arcServer.ResourceId, "Attest licensing eligibility and enable Azure benefits")) {
        exit 0
    }

    Write-Host "Enabling..." -ForegroundColor Yellow
    $licenseConfig = @{
        softwareAssurance = @{
            softwareAssuranceCustomer = $true
        }
    }

    New-AzResource -ResourceId $profilePath -Properties $licenseConfig -Location $arcServer.Location -ApiVersion $api -Force -ErrorAction Stop | Out-Null
    Assert-ArcBenefitsEnabled -ResourceId $profilePath -ApiVersion $api
    Write-Host "Done`n" -ForegroundColor Green
} catch {
    Write-Host "Failed: $($_.Exception.Message)`n" -ForegroundColor Red
    exit 1
}
exit 0
