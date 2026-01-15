# Azure Arc Management

PowerShell scripts for managing Arc-enabled servers and SQL licensing.

## Prerequisites

Before using any scripts, run these commands once:

```powershell
Install-Module Az.ConnectedMachine -Force -Scope CurrentUser
Install-Module Az.Accounts -Force -Scope CurrentUser
Install-Module Az.Resources -Force -Scope CurrentUser
Connect-AzAccount
Set-AzContext -SubscriptionId "your-subscription-id"
```

## Azure Benefits

Enable Software Assurance attestation for Arc Windows servers.

### Enable-AzureArcSABenefits-Single.ps1

Enable benefits for a single server.

```powershell
.\Enable-AzureArcSABenefits-Single.ps1 -ResourceGroupName "my-rg" -MachineName "server-01"
```

**Parameters:**
- `ResourceGroupName`: Resource group name
- `MachineName`: Arc server name

### Enable-AzureArcSABenefits-ResourceGroup.ps1

Enable benefits for all servers in a resource group.

```powershell
.\Enable-AzureArcSABenefits-ResourceGroup.ps1 -ResourceGroupName "my-rg"
```

**Parameters:**
- `ResourceGroupName`: Resource group name
- `ExcludeMachines`: (Optional) Array of machine names to skip

```powershell
.\Enable-AzureArcSABenefits-ResourceGroup.ps1 -ResourceGroupName "my-rg" -ExcludeMachines "dev-server","test-vm"
```

### Enable-AzureArcSABenefits-All.ps1

Enable benefits for all servers in the subscription.

```powershell
.\Enable-AzureArcSABenefits-All.ps1
```

**Parameters:**
- `ExcludeMachines`: (Optional) Array of machine names to skip

```powershell
.\Enable-AzureArcSABenefits-All.ps1 -ExcludeMachines "dev-server","test-vm"
```

## SQL Licensing

Update license type for SQL servers.

### License Types

- `PAYG`: Pay-as-you-go billing through Azure
- `Paid`: License with Software Assurance or SQL subscription
- `LicenseOnly`: Developer, Express, Evaluation, or Server/CAL without SA

### Update-ArcSQLLicenseType-Single.ps1

Update license type for a single SQL server.

```powershell
.\Update-ArcSQLLicenseType-Single.ps1 -ResourceGroupName "my-rg" -MachineName "sql-server-01" -LicenseType "Paid"
```

**Parameters:**
- `ResourceGroupName`: Resource group name
- `MachineName`: Arc server name
- `LicenseType`: PAYG, Paid, or LicenseOnly

### Update-ArcSQLLicenseType-ResourceGroup.ps1

Update license type for all SQL servers in a resource group.

```powershell
.\Update-ArcSQLLicenseType-ResourceGroup.ps1 -ResourceGroupName "my-rg" -LicenseType "Paid"
```

**Parameters:**
- `ResourceGroupName`: Resource group name
- `LicenseType`: PAYG, Paid, or LicenseOnly

### Update-ArcSQLLicenseType-All.ps1

Update license type for all SQL servers in the subscription.

```powershell
.\Update-ArcSQLLicenseType-All.ps1 -LicenseType "Paid"
```

**Parameters:**
- `LicenseType`: PAYG, Paid, or LicenseOnly

### Enable-AzureArcSQLSABenefits.ps1

Update license type for a single SQL server (alternative naming).

```powershell
.\Enable-AzureArcSQLSABenefits.ps1 -ResourceGroupName "my-rg" -MachineName "sql-server-01" -LicenseType "Paid"
```

**Parameters:**
- `ResourceGroupName`: Resource group name
- `MachineName`: Arc server name
- `LicenseType`: PAYG, Paid, or LicenseOnly

## Policy

### arc-windows-sa-remediation-policy.json

Azure Policy that enables Software Assurance benefits for Arc Windows servers.

## Queries

### arc-licensing-graph-query.kql

KQL query for Resource Graph Explorer to view licensing status across Arc resources.

## Notes

- All scripts preserve existing extension settings when updating
- Scripts check for current state and skip unchanged machines
- Proper error handling with detailed failure messages
- Summary output shows success, skipped, and failed counts
