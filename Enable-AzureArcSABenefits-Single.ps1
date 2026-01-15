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

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$MachineName
)

$ErrorActionPreference = "Stop"

Write-Host "`nEnabling Azure benefits for Arc server" -ForegroundColor Cyan
Write-Host "Machine: $MachineName (rg: $ResourceGroupName)`n" -ForegroundColor Gray

# Get the Arc server resource
$arcServer = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $MachineName -ResourceType 'Microsoft.HybridCompute/machines' -ErrorAction SilentlyContinue

if (-not $arcServer) {
    Write-Host "Machine not found`n" -ForegroundColor Red
    exit 1
}

$profilePath = $arcServer.ResourceId + '/licenseProfiles/default'
$api = '2023-10-03-preview'

# Check current status
try {
    $existingProfile = Get-AzResource -ResourceId $profilePath -ApiVersion $api -ErrorAction SilentlyContinue
    $isEnabled = $existingProfile.Properties.softwareAssurance.softwareAssuranceCustomer
    
    if ($isEnabled -eq $true) {
        Write-Host "Already enabled`n" -ForegroundColor Green
        exit 0
    }
} catch {
    # Not configured yet
}

# Enable Azure benefits
Write-Host "Enabling..." -ForegroundColor Yellow

$licenseConfig = @{
    softwareAssurance = @{
        softwareAssuranceCustomer = $true
    }
}

try {
    $result = New-AzResource -ResourceId $profilePath -Properties $licenseConfig -Location $arcServer.Location -ApiVersion $api -Force
    Write-Host "Done`n" -ForegroundColor Green
    
    $updatedProfile = Get-AzResource -ResourceId $profilePath -ApiVersion $api
    $verifiedStatus = $updatedProfile.Properties.softwareAssurance.softwareAssuranceCustomer
    
    if ($verifiedStatus -ne $true) {
        Write-Host "Warning: Verification shows: $verifiedStatus`n" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Failed: $($_.Exception.Message)`n" -ForegroundColor Red
    exit 1
}
