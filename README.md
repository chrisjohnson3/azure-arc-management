# Azure Arc Management

Scripts and tools for managing Arc-enabled servers and SQL licensing.

## Prerequisites

Install required modules and connect to Azure:

```powershell
Install-Module Az.ConnectedMachine -Force -Scope CurrentUser
Install-Module Az.Accounts -Force -Scope CurrentUser
Install-Module Az.Resources -Force -Scope CurrentUser
Connect-AzAccount
Set-AzContext -SubscriptionId "your-subscription-id"
```

## SQL License Compliance Monitoring

### Arc SQL License Compliance Workbook

Dashboard for monitoring SQL Server license compliance across Arc-enabled servers.

**Features:**
- Displays all Arc SQL instances with current license types
- Filters by online/offline status
- Color-coded compliance indicators
- Configurable target license type
- Excludes service instances (SSIS, SSRS, SSAS) - shows database engine only

**Deployment Steps:**

1. Navigate to Azure Portal → **Monitor** → **Workbooks** → **+ New**
2. Click the **</>** (Advanced Editor) button
3. Select **Gallery Template** tab
4. Copy and paste the contents of `arc-sql-license-workbook.json`
5. Click **Apply**, then **Done Editing**
6. Select your subscription(s) from the dropdown
7. Save the workbook (recommended name: "Arc SQL License Compliance")

**Usage:**
- **Target License Type**: Select the license type to enforce (Paid, PAYG, LicenseOnly)
- **Show Offline Instances**: Toggle to include or exclude disconnected servers
- **Summary tiles**: Quick overview of instance counts and compliance status
- **Instance table**: Detailed view of each server's configuration and status

**Compliance Indicators:**
- ✓ Green = Compliant (using target license type)
- ⚠ Yellow = Non-compliant (remediation needed)
- Gray = Offline (server disconnected)

**Remediation Options:**

After identifying non-compliant instances:

1. **Manual remediation**: Use the scripts below to update individual servers or resource groups
2. **Automated remediation**: Deploy the automation runbook (files in `runbook/` folder) for on-demand fixes
   - Runbook does not run automatically unless scheduled
   - Execute on-demand when ready to remediate

---

## Azure Benefits

Enable Software Assurance attestation for Arc Windows servers.

### Enable-AzureArcSABenefits-Single.ps1

Enable benefits for a single server:

```powershell
.\Enable-AzureArcSABenefits-Single.ps1 -ResourceGroupName "my-rg" -MachineName "server-01"
```

**Parameters:**
- `ResourceGroupName`: Resource group name
- `MachineName`: Arc server name

### Enable-AzureArcSABenefits-ResourceGroup.ps1

Enable benefits for all servers in a resource group:

```powershell
.\Enable-AzureArcSABenefits-ResourceGroup.ps1 -ResourceGroupName "my-rg"
```

**Parameters:**
- `ResourceGroupName`: Resource group name
- `ExcludeMachines`: (Optional) Machines to exclude from operation

```powershell
.\Enable-AzureArcSABenefits-ResourceGroup.ps1 -ResourceGroupName "my-rg" -ExcludeMachines "dev-server","test-vm"
```

### Enable-AzureArcSABenefits-All.ps1

Enable benefits for all servers in the subscription:

```powershell
.\Enable-AzureArcSABenefits-All.ps1
```

**Parameters:**
- `ExcludeMachines`: (Optional) Machines to exclude from operation

```powershell
.\Enable-AzureArcSABenefits-All.ps1 -ExcludeMachines "dev-server","test-vm"
```

## SQL Licensing

Update license type for Arc-enabled SQL servers.

### License Types

- `PAYG`: Pay-as-you-go billing through Azure
- `Paid`: Software Assurance or SQL Server subscription
- `LicenseOnly`: Bring your own license (Developer, Express, Evaluation, or Server/CAL without SA)

### Update-ArcSQLLicenseType-Single.ps1

Update license type for a single SQL server:

```powershell
.\Update-ArcSQLLicenseType-Single.ps1 -ResourceGroupName "my-rg" -MachineName "sql-server-01" -LicenseType "Paid"
```

**Parameters:**
- `ResourceGroupName`: Resource group name
- `MachineName`: Arc server name
- `LicenseType`: PAYG, Paid, or LicenseOnly

### Update-ArcSQLLicenseType-ResourceGroup.ps1

Update license type for all SQL servers in a resource group:

```powershell
.\Update-ArcSQLLicenseType-ResourceGroup.ps1 -ResourceGroupName "my-rg" -LicenseType "Paid"
```

**Parameters:**
- `ResourceGroupName`: Resource group name
- `LicenseType`: PAYG, Paid, or LicenseOnly

### Update-ArcSQLLicenseType-All.ps1

Update license type for all SQL servers in the subscription:

```powershell
.\Update-ArcSQLLicenseType-All.ps1 -LicenseType "Paid"
```

**Parameters:**
- `LicenseType`: PAYG, Paid, or LicenseOnly

### Enable-AzureArcSQLSABenefits.ps1

Alternative script for single server license updates:

```powershell
.\Enable-AzureArcSQLSABenefits.ps1 -ResourceGroupName "my-rg" -MachineName "sql-server-01" -LicenseType "Paid"
```

**Parameters:**
- `ResourceGroupName`: Resource group name
- `MachineName`: Arc server name
- `LicenseType`: PAYG, Paid, or LicenseOnly

## Policy

### arc-windows-sa-remediation-policy.json

Azure Policy definition for automatically enabling Software Assurance benefits on Arc Windows servers.

## Queries

### arc-licensing-graph-query.kql

Resource Graph query for viewing licensing status across Arc resources.

### arc-windows-esu-cost-estimate.kql

Resource Graph query that returns a per-server ESU cost estimate for Arc-enabled Windows servers.

Identifies servers running ESU-eligible OS versions (Windows Server 2012, 2012 R2, and 2016), applies the 8-core minimum licensing rule, and calculates monthly and yearly ESU costs based on current Microsoft ESU pricing.

**ESU Pricing (per core/month):**
- Windows Server 2012 / 2012 R2 Standard: $4.74
- Windows Server 2012 / 2012 R2 Datacenter: $27.50
- Windows Server 2016 Standard: $4.74 *(ESU begins January 2027)*
- Windows Server 2016 Datacenter: $27.50 *(ESU begins January 2027)*

**Notes:**
- Azure VMs are excluded — ESUs are provided at no cost for Azure-hosted workloads
- Pricing is hardcoded based on current Microsoft ESU rates — update if rates change
- The 8-core minimum per server is applied per Microsoft licensing requirements
- Results are sorted by yearly ESU cost descending
## Notes

- Scripts skip servers already configured with the target setting
- Existing configurations are preserved during updates
- Each script provides a summary of successful, skipped, and failed operations
- The workbook provides monitoring only - remediation requires manual action or runbook deployment
