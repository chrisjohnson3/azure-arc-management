# Azure Arc Management

Simple, customer-operated PowerShell scripts to record Windows Server Software Assurance attestation and update SQL Server license settings, one server or a batch at a time.

These scripts work on **already Arc-enabled servers**. They do not install the Arc agent, purchase licenses, or verify licensing entitlement.

## Before you run

- Use **PowerShell 7** (`pwsh`), not Windows PowerShell 5.1.
- Download or clone the repository and keep `ArcManagement.Helpers.ps1` beside the six scripts.
- Sign in with permission to read the selected machines and update their license profiles or SQL extensions.
- Confirm the subscription and the licensing eligibility of every selected server with your licensing owner.
- For Windows benefits, only select supported Windows Server machines with active Software Assurance or qualifying subscription coverage. SQL SA does not establish Windows Server SA eligibility. See the [benefit requirements and terms](https://learn.microsoft.com/azure/azure-arc/servers/windows-server-management-overview).
- The SQL scripts target the `WindowsAgent.SqlServer` extension on Windows; Linux SQL extensions are not included.

Run from the downloaded repository in PowerShell 7:

```powershell
Install-Module Az.Accounts -Force -Scope CurrentUser
Install-Module Az.Resources -Force -Scope CurrentUser
Install-Module Az.ConnectedMachine -Force -Scope CurrentUser
Connect-AzAccount
Set-AzContext -SubscriptionId "your-subscription-id"
```

## Start small, then expand

1. Preview with `-WhatIf`. This reads Azure to discover targets but performs no writes.
2. Run against one approved server and check the saved setting in the Azure portal.
3. Preview the resource group or subscription, review the displayed targets, then run the batch.

Scripts show the subscription and ask for confirmation before changes. Bulk scripts ask once for the displayed batch. `-Confirm:$false` bypasses that prompt: only use it after reviewing and approving the targets.

```powershell
# Preview one Windows Server attestation, then apply it.
.\Enable-AzureArcSABenefits-Single.ps1 -ResourceGroupName "my-rg" -MachineName "server-01" -WhatIf
.\Enable-AzureArcSABenefits-Single.ps1 -ResourceGroupName "my-rg" -MachineName "server-01"

# Preview a batch, then apply it to the approved resource group.
.\Enable-AzureArcSABenefits-ResourceGroup.ps1 -ResourceGroupName "my-rg" -ExcludeMachines "dev-server","test-vm" -WhatIf
.\Enable-AzureArcSABenefits-ResourceGroup.ps1 -ResourceGroupName "my-rg" -ExcludeMachines "dev-server","test-vm"
```

## Windows Server benefits attestation

Confirming an attestation run declares that the selected Windows Server machines have the required SA/subscription coverage. **The script records your declaration; it does not validate entitlement.** Bulk scripts select Windows machines, not a licensing-approved inventory: use an approved scope and exclusions.

| Script | Scope | Parameters |
| --- | --- | --- |
| `Enable-AzureArcSABenefits-Single.ps1` | One server | `ResourceGroupName`, `MachineName` |
| `Enable-AzureArcSABenefits-ResourceGroup.ps1` | Windows machines in a resource group | `ResourceGroupName`, optional `ExcludeMachines` |
| `Enable-AzureArcSABenefits-All.ps1` | Windows machines in the current subscription | Optional `ExcludeMachines` |

```powershell
.\Enable-AzureArcSABenefits-All.ps1 -ExcludeMachines "dev-server","test-vm" -WhatIf
```

The scripts verify the saved attestation flag. Benefit activation can take up to ten minutes; a saved flag is not proof that every benefit is active or that the server is properly licensed.

## SQL Server license settings

Choose the value that matches your actual entitlement:

- `PAYG`: Pay-as-you-go through Azure. **Switching to PAYG can start Azure billing.**
- `Paid`: SQL Server license with active Software Assurance or a qualifying SQL Server subscription.
- `LicenseOnly`: License without SA, or a free Developer, Express, or Evaluation edition. See [SQL licensing guidance](https://learn.microsoft.com/sql/sql-server/azure-arc/manage-license-billing) for Server+CAL, SPLA, and other special cases.

Settings apply at the machine's Windows SQL extension level, not to one individually selected SQL instance.

| Script | Scope | Parameters |
| --- | --- | --- |
| `Update-ArcSQLLicenseType-Single.ps1` | One machine | `ResourceGroupName`, `MachineName`, `LicenseType` |
| `Update-ArcSQLLicenseType-ResourceGroup.ps1` | Windows SQL extensions in a resource group | `ResourceGroupName`, `LicenseType` |
| `Update-ArcSQLLicenseType-All.ps1` | Windows SQL extensions in the current subscription | `LicenseType` |

```powershell
.\Update-ArcSQLLicenseType-Single.ps1 -ResourceGroupName "my-rg" -MachineName "sql-01" -LicenseType "Paid" -WhatIf
.\Update-ArcSQLLicenseType-Single.ps1 -ResourceGroupName "my-rg" -MachineName "sql-01" -LicenseType "Paid"

.\Update-ArcSQLLicenseType-ResourceGroup.ps1 -ResourceGroupName "my-rg" -LicenseType "Paid" -WhatIf
.\Update-ArcSQLLicenseType-ResourceGroup.ps1 -ResourceGroupName "my-rg" -LicenseType "Paid"

.\Update-ArcSQLLicenseType-All.ps1 -LicenseType "Paid" -WhatIf
```

Existing public SQL extension settings are retained. If `SqlManagement` is absent, the scripts enable it as in the documented SQL extension configuration.

## Results and failures

- Already matching settings are skipped without writes.
- Changes are read back before being reported as successful, with up to three checks.
- Exit code `0` means the requested saved settings were verified/already present, or the run was previewed/cancelled. Exit code `1` means a failure. A preview is not verification of current settings.
- Bulk scripts continue after an individual update failure and print the affected machine and error.
- Discovery/access errors stop the run rather than silently omitting machines.
- Batches are not transactional: earlier successful changes remain if a later operation fails. Check the saved settings before retrying; there is no automatic rollback.

## Additional tools

The policy, workbook, and KQL files remain available for reference but are **not part of the recommended customer bulk-script workflow**:

- `arc-windows-sa-remediation-policy.json`: automatic attestation policy. Requires separate validation of child-resource matching, identity permissions, and licensing-approved scope before assignment.
- `arc-sql-license-workbook.json`: configuration dashboard. Its name-based grouping can merge servers/instances; do not use its green indicators as licensing evidence.
- `arc-licensing-graph-query.kql`: resource inventory query, not an entitlement audit.
- `arc-windows-esu-cost-estimate.kql`: legacy illustrative estimate, not a current quote. It does not distinguish physical/virtual licensing correctly. Windows Server 2012/2012 R2 Arc ESU coverage ended October 2026. Use [current ESU guidance](https://learn.microsoft.com/azure/azure-arc/servers/license-extended-security-updates) for planning.

## Offline tests

```powershell
pwsh -NoProfile -File .\tests\Test-ArcScripts.ps1
```

Tests use mocked Azure commands and never connect to Azure. They do not replace a single-server validation in your environment.
