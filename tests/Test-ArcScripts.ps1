#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$ScriptName,
    [string]$Scenario
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent

if ($ScriptName) {
    class TestHttpException : System.Exception {
        [object]$Response
        TestHttpException([int]$status) : base("HTTP $status") {
            $this.Response = [pscustomobject]@{ StatusCode = $status }
        }
    }

    $global:state = @{
        Attempts = @()
        Saved = @{}
        VerifyReads = @{}
        Sleeps = 0
        Reads = 0
    }
    $machines = @(
        [pscustomobject]@{
            Name = 'server-a'; ResourceGroupName = 'rg-a'; Location = 'eastus'
            ResourceId = '/subscriptions/test-sub/resourceGroups/rg-a/providers/Microsoft.HybridCompute/machines/server-a'
            Properties = @{ osName = 'Microsoft Windows Server 2022 Standard' }
        },
        [pscustomobject]@{
            Name = 'server-b'; ResourceGroupName = 'rg-a'; Location = 'eastus'
            ResourceId = '/subscriptions/test-sub/resourceGroups/rg-a/providers/Microsoft.HybridCompute/machines/server-b'
            Properties = @{ osName = 'Microsoft Windows Server 2022 Standard' }
        }
    )
    if ($Scenario -eq 'LinuxOnly') {
        $machines | ForEach-Object { $_.Properties.osName = 'Linux' }
    }
    if ($Scenario -eq 'SingleTarget') { $machines = @($machines[0]) }

    function Get-AzContext {
        if ($Scenario -ne 'NoContext') {
            [pscustomobject]@{ Subscription = @{ Name = 'Test subscription'; Id = 'test-sub' } }
        }
    }

    function Get-AzResourceGroup {
        [CmdletBinding()]
        param()
        $state.Reads++
        if ($Scenario -eq 'DiscoveryDenied') { throw [TestHttpException]::new(403) }
        [pscustomobject]@{ ResourceGroupName = 'rg-a' }
    }

    function Get-AzConnectedMachine {
        [CmdletBinding()]
        param([string]$ResourceGroupName)
        $state.Reads++
        if ($Scenario -eq 'DiscoveryDenied') { throw [TestHttpException]::new(403) }
        if ($Scenario -ne 'NoTargets') { $machines }
    }

    function Get-AzResource {
        [CmdletBinding()]
        param(
            [string]$ResourceId, [string]$ResourceType, [string]$ResourceGroupName,
            [string]$Name, [string]$ApiVersion, [switch]$ExpandProperties
        )
        $state.Reads++
        if ($Scenario -eq 'DiscoveryDenied') { throw [TestHttpException]::new(403) }
        if ($ResourceId -like '*/licenseProfiles/default') {
            if ($Scenario -eq 'ReadDenied') { throw [TestHttpException]::new(403) }
            $machineName = ($ResourceId -split '/')[-3]
            if ($Scenario -eq 'MissingProfile' -and -not $state.Saved.ContainsKey($machineName)) {
                throw [TestHttpException]::new(404)
            }
            $enabled = $Scenario -eq 'Already'
            if ($state.Saved.ContainsKey($machineName)) {
                if ($Scenario -eq 'VerifyReadDenied') { throw [TestHttpException]::new(403) }
                $state.VerifyReads[$machineName] = 1 + $state.VerifyReads[$machineName]
                $enabled = $Scenario -ne 'VerificationMismatch' -and
                    ($Scenario -ne 'Delayed' -or $state.VerifyReads[$machineName] -gt 1)
            }
            return [pscustomobject]@{
                Properties = @{ softwareAssurance = @{ softwareAssuranceCustomer = $enabled } }
            }
        }
        if ($Scenario -eq 'NoTargets') { return }
        if ($ResourceId) { return $machines | Where-Object ResourceId -EQ $ResourceId }
        if ($Name) { return $machines | Where-Object Name -EQ $Name }
        $machines
    }

    function Get-AzConnectedMachineExtension {
        [CmdletBinding()]
        param([string]$ResourceGroupName, [string]$MachineName, [string]$Name)
        $state.Reads++
        if ($Scenario -eq 'DiscoveryDenied') { throw [TestHttpException]::new(403) }
        if ($Scenario -in @('NoTargets', 'MissingExtension', 'LinuxOnly')) { return }
        if ($Name -and $Scenario -eq 'ReadDenied') { throw [TestHttpException]::new(403) }
        $licenseType = if ($Scenario -eq 'Already') { 'Paid' } elseif ($Scenario -eq 'TargetLicenseOnly') { 'PAYG' } else { 'LicenseOnly' }
        if ($Name -and $state.Saved.ContainsKey($MachineName)) {
            if ($Scenario -eq 'VerifyReadDenied') { throw [TestHttpException]::new(403) }
            $state.VerifyReads[$MachineName] = 1 + $state.VerifyReads[$MachineName]
            if ($Scenario -ne 'VerificationMismatch' -and
                ($Scenario -ne 'Delayed' -or $state.VerifyReads[$MachineName] -gt 1)) {
                $licenseType = $state.Saved[$MachineName].LicenseType
            }
        }
        $settings = @{
            LicenseType = $licenseType
            SqlManagement = @{ IsEnabled = $false }
            Nested = @{ Value = 42 }
            ExcludedSqlInstances = @('KEEP')
        }
        if ($Scenario -eq 'MissingSqlManagement') { $settings.Remove('SqlManagement') }
        [pscustomobject]@{ Name = 'WindowsAgent.SqlServer'; Setting = $settings }
    }

    function New-AzResource {
        [CmdletBinding()]
        param([string]$ResourceId, [hashtable]$Properties, [string]$Location, [string]$ApiVersion, [switch]$Force)
        $machineName = ($ResourceId -split '/')[-3]
        $state.Attempts += $machineName
        if ($Scenario -eq 'WriteFailure' -or ($Scenario -eq 'PartialFailure' -and $machineName -eq 'server-b')) {
            throw 'Simulated write failure'
        }
        $state.Saved[$machineName] = $Properties
    }

    function Update-AzConnectedMachineExtension {
        [CmdletBinding()]
        param([string]$ResourceGroupName, [string]$MachineName, [string]$Name, [hashtable]$Setting)
        $state.Attempts += $MachineName
        if ($Scenario -eq 'WriteFailure' -or ($Scenario -eq 'PartialFailure' -and $MachineName -eq 'server-b')) {
            throw 'Simulated write failure'
        }
        $state.Saved[$MachineName] = $Setting
    }

    function Start-Sleep {
        param([int]$Seconds)
        $state.Sleeps++
    }

    $arguments = @{}
    if ($ScriptName -notlike '*-All.ps1') { $arguments.ResourceGroupName = 'rg-a' }
    if ($ScriptName -like '*-Single.ps1') { $arguments.MachineName = 'server-a' }
    if ($ScriptName -like 'Update-*') {
        $arguments.LicenseType = switch ($Scenario) {
            'InvalidLicense' { 'Invalid' }
            'TargetPAYG' { 'PAYG' }
            'TargetLicenseOnly' { 'LicenseOnly' }
            default { 'Paid' }
        }
    }
    if ($Scenario -eq 'WhatIf') {
        $arguments.WhatIf = $true
    } elseif ($Scenario -ne 'ConfirmationRequired') {
        $arguments.Confirm = $false
    }
    if ($Scenario -eq 'Excluded') { $arguments.ExcludeMachines = @('server-a') }
    if ($Scenario -eq 'AllExcluded') { $arguments.ExcludeMachines = @('server-a', 'server-b') }

    $global:LASTEXITCODE = 0
    try {
        & (Join-Path $repo $ScriptName) @arguments
        $code = $LASTEXITCODE
    } catch {
        Write-Host "Caught failure: $($_.Exception.Message)"
        $code = 1
    }
    Write-Host ('TEST_STATE:' + ($state | ConvertTo-Json -Depth 12 -Compress))
    exit $code
}

$scripts = @(
    'Enable-AzureArcSABenefits-All.ps1',
    'Enable-AzureArcSABenefits-ResourceGroup.ps1',
    'Enable-AzureArcSABenefits-Single.ps1',
    'Update-ArcSQLLicenseType-All.ps1',
    'Update-ArcSQLLicenseType-ResourceGroup.ps1',
    'Update-ArcSQLLicenseType-Single.ps1'
)
$passed = 0
$failed = 0

foreach ($script in $scripts) {
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repo $script), [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) { throw "$script has syntax errors: $parseErrors" }
    if ($ast.ScriptRequirements.RequiredPSVersion.Major -lt 7) { throw "$script must require PowerShell 7." }
    $binding = $ast.ParamBlock.Attributes | Where-Object TypeName -Match 'CmdletBinding'
    if ($binding.Extent.Text -notmatch "SupportsShouldProcess=\`$true" -or
        $binding.Extent.Text -notmatch "ConfirmImpact='High'") {
        throw "$script must support WhatIf and require confirmation."
    }

    $scenarios = @(
        'Success', 'WhatIf', 'Already', 'NoContext', 'NoTargets', 'DiscoveryDenied',
        'ReadDenied', 'WriteFailure', 'VerificationMismatch', 'VerifyReadDenied',
        'Delayed', 'ConfirmationRequired', 'LinuxOnly'
    )
    if ($script -notlike '*-Single.ps1') { $scenarios += @('PartialFailure', 'SingleTarget') }
    if ($script -like 'Enable-*') {
        $scenarios += 'MissingProfile'
        if ($script -notlike '*-Single.ps1') { $scenarios += @('Excluded', 'AllExcluded') }
    } else {
        $scenarios += @('MissingExtension', 'InvalidLicense', 'MissingSqlManagement', 'TargetPAYG', 'TargetLicenseOnly')
    }

    foreach ($scenario in $scenarios) {
        $executable = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
        $output = & (Join-Path $PSHOME $executable) -NoProfile -NonInteractive -File $PSCommandPath -ScriptName $script -Scenario $scenario 2>&1
        $exitCode = $LASTEXITCODE
        $marker = @($output | Where-Object { "$_" -like 'TEST_STATE:*' }) | Select-Object -Last 1
        try {
            if (-not $marker) { throw "Child did not report state: $($output -join "`n")" }
            $result = "$marker".Substring(11) | ConvertFrom-Json -AsHashtable
            $targetCount = if ($script -like '*-Single.ps1' -or $scenario -in @('Excluded', 'SingleTarget')) { 1 } else { 2 }
            $success = $scenario -in @('Success', 'WhatIf', 'Already', 'Delayed', 'MissingProfile', 'Excluded', 'MissingSqlManagement', 'SingleTarget', 'TargetPAYG', 'TargetLicenseOnly')
            $expectedCode = if ($success) { 0 } else { 1 }
            $expectedAttempts = if ($scenario -in @(
                'Success', 'Delayed', 'MissingProfile', 'Excluded', 'MissingSqlManagement',
                'WriteFailure', 'VerificationMismatch', 'VerifyReadDenied', 'PartialFailure',
                'SingleTarget', 'TargetPAYG', 'TargetLicenseOnly'
            )) { $targetCount } else { 0 }
            if ($exitCode -ne $expectedCode) { throw "Exit $exitCode; expected $expectedCode." }
            if ($result.Attempts.Count -ne $expectedAttempts) { throw "Writes $($result.Attempts.Count); expected $expectedAttempts." }
            if ($scenario -eq 'PartialFailure' -and -not $result.Saved.ContainsKey('server-a')) {
                throw 'Earlier successful change must remain after a later failure.'
            }
            if ($scenario -eq 'Excluded' -and $result.Saved.ContainsKey('server-a')) { throw 'Excluded machine was updated.' }
            if ($scenario -eq 'NoContext' -and $result.Reads -ne 0) { throw 'Discovery ran without a context.' }
            if ($scenario -eq 'Delayed' -and $result.Sleeps -ne $targetCount) { throw 'Read-back retry was not exercised.' }
            if ($scenario -eq 'VerificationMismatch' -and $result.Sleeps -ne (2 * $targetCount)) {
                throw 'Verification must stop after three checks.'
            }
            if ($scenario -in @('TargetPAYG', 'TargetLicenseOnly')) {
                $expectedType = if ($scenario -eq 'TargetPAYG') { 'PAYG' } else { 'LicenseOnly' }
                foreach ($settings in $result.Saved.Values) {
                    if ($settings.LicenseType -ne $expectedType) { throw "Expected saved license type $expectedType." }
                }
            }
            if ($script -like 'Update-*' -and $scenario -in @('Success', 'MissingSqlManagement')) {
                foreach ($settings in $result.Saved.Values) {
                    if ($settings.LicenseType -ne 'Paid' -or $settings.Nested.Value -ne 42 -or
                        $settings.ExcludedSqlInstances[0] -ne 'KEEP') { throw 'SQL settings were not preserved.' }
                    $expectedManagement = $scenario -eq 'MissingSqlManagement'
                    if ($settings.SqlManagement.IsEnabled -ne $expectedManagement) { throw 'Unexpected SqlManagement change.' }
                }
            }
            $passed++
            Write-Host "PASS $script / $scenario"
        } catch {
            $failed++
            Write-Host "FAIL $script / $scenario : $($_.Exception.Message)" -ForegroundColor Red
            $output | ForEach-Object { Write-Host "$_" }
        }
    }
}

Write-Host "`n$passed passed; $failed failed."
if ($failed -gt 0) { exit 1 }
exit 0
