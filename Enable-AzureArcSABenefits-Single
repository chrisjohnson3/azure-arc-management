<#
.SYNOPSIS
    Enable Azure Benefits for a single Arc-enabled Windows Server

.DESCRIPTION
    This script enables the "Activate Azure benefits" checkbox for one Arc-enabled Windows Server.

.PREREQUISITES
    Run these commands ONCE before using this script:
    1. Install-Module Az.Accounts -Force -Scope CurrentUser
    2. Install-Module Az.Resources -Force -Scope CurrentUser
    3. Connect-AzAccount
    4. Set-AzContext -SubscriptionId "your-subscription-id"

.PARAMETER ResourceGroupName
    The name of the resource group containing the Arc server

.PARAMETER MachineName
    The name of the Arc server

.EXAMPLE
    .\Enable-AzureArcSABenefits-Single.ps1 -ResourceGroupName "your-rg-name" -MachineName "server-name"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$MachineName
)

$ErrorActionPreference = "Stop"

Write-Host "`nEnabling Azure Benefits for Arc Windows Server" -ForegroundColor Cyan
Write-Host "Machine: $MachineName" -ForegroundColor Gray
Write-Host "Resource Group: $ResourceGroupName`n" -ForegroundColor Gray

# Get the Arc server resource
$arcServer = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $MachineName -ResourceType 'Microsoft.HybridCompute/machines' -ErrorAction SilentlyContinue

if (-not $arcServer) {
    Write-Host "✗ Machine not found`n" -ForegroundColor Red
    exit 1
}

$profilePath = $arcServer.ResourceId + '/licenseProfiles/default'
$api = '2023-10-03-preview'

# Check current status
Write-Host "Checking current status..." -ForegroundColor Yellow
try {
    $existingProfile = Get-AzResource -ResourceId $profilePath -ApiVersion $api -ErrorAction SilentlyContinue
    $isEnabled = $existingProfile.Properties.softwareAssurance.softwareAssuranceCustomer
    Write-Host "Current Status: $isEnabled`n" -ForegroundColor Gray
    
    if ($isEnabled -eq $true) {
        Write-Host "✓ Azure benefits already enabled - no action needed`n" -ForegroundColor Green
        exit 0
    }
} catch {
    Write-Host "Current Status: Not configured`n" -ForegroundColor Gray
}

# Enable Azure benefits
Write-Host "Enabling Azure benefits..." -ForegroundColor Yellow

$licenseConfig = @{
    softwareAssurance = @{
        softwareAssuranceCustomer = $true
    }
}

try {
    $result = New-AzResource -ResourceId $profilePath -Properties $licenseConfig -Location $arcServer.Location -ApiVersion $api -Force
    Write-Host "✓ SUCCESS - Azure benefits enabled`n" -ForegroundColor Green
    
    # Verify
    Write-Host "Verifying..." -ForegroundColor Yellow
    $updatedProfile = Get-AzResource -ResourceId $profilePath -ApiVersion $api
    $verifiedStatus = $updatedProfile.Properties.softwareAssurance.softwareAssuranceCustomer
    
    if ($verifiedStatus -eq $true) {
        Write-Host "✓ Verified: Azure benefits are now enabled`n" -ForegroundColor Green
    } else {
        Write-Host "⚠ Warning: Verification shows: $verifiedStatus`n" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)`n" -ForegroundColor Red
    exit 1
}
