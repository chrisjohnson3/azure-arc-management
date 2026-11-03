#Requires -Version 7.0

function Get-ArcLicenseProfile {
    param(
        [string]$ResourceId,
        [string]$ApiVersion
    )

    try {
        Get-AzResource -ResourceId $ResourceId -ApiVersion $ApiVersion -ExpandProperties -ErrorAction Stop
    } catch {
        # Only an HTTP 404 means the profile has not been configured.
        if ($_.Exception.Response.StatusCode -ne 404) {
            throw
        }
    }
}

function Assert-ArcBenefitsEnabled {
    param(
        [string]$ResourceId,
        [string]$ApiVersion
    )

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $profile = Get-ArcLicenseProfile -ResourceId $ResourceId -ApiVersion $ApiVersion
        if ($profile.Properties.softwareAssurance.softwareAssuranceCustomer -eq $true) {
            return
        }
        if ($attempt -lt 3) {
            Start-Sleep -Seconds 2
        }
    }
    throw "Attestation was not verified for $ResourceId. Check its saved status before retrying."
}

function Assert-ArcSQLLicenseType {
    param(
        [string]$ResourceGroupName,
        [string]$MachineName,
        [string]$LicenseType
    )

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $extension = Get-AzConnectedMachineExtension -ResourceGroupName $ResourceGroupName -MachineName $MachineName -Name "WindowsAgent.SqlServer" -ErrorAction Stop
        if ($extension.Setting["LicenseType"] -eq $LicenseType) {
            return
        }
        if ($attempt -lt 3) {
            Start-Sleep -Seconds 2
        }
    }
    throw "License type $LicenseType was not verified for $ResourceGroupName/$MachineName. Check its saved status before retrying."
}
