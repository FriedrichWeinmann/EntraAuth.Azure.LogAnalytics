# EntraAuth.Azure.LogAnalytics

Welcome to the `EntraAuth.Azure.LogAnalytics` project, a client library/module for PowerShell to interact with Azure Log Analytics and related resources.
Key focus is on enabling the use of Log Analytics as a logging target for PowerShell code.

## Installation

To install the module, run:

```powershell
Install-Module -Name 'EntraAuth.Azure.LogAnalytics' -Scope CurrentUser
```

Alternatively, if you have any trouble getting modules installed, this might work instead:

```powershell
Invoke-WebRequest 'https://raw.githubusercontent.com/PowershellFrameworkCollective/PSFramework.NuGet/refs/heads/master/bootstrap.ps1' -UseBasicParsing | Invoke-Expression
Install-PSFModule -Name 'EntraAuth.Azure.LogAnalytics'
```

## Profit

### Authenticate

```powershell
Connect-EntraService -Service Azure -ClientID Azure
Connect-EntraService -Service Graph -ClientID Azure -UseRefreshToken
```

### Simple Actions

> List all Workspaces in the tenant you have access to

```powershell
Get-EaaSubscription | Get-EalaWorkspace
```

> List all Tables in the target workspace

```powershell
Get-EalaWorkspace -Subscription "Fred's Test Subscription" -Name pslogging | Get-EalaTable
```

> Create a Log Analytics Workspace

Will be created in the location the Resource Group belongs to.

```powershell
New-EalaWorkspace -Subscription '0c3d2c12-2636-40de-aa52-dbf19a79a357' -ResourceGroup rg_scripting -Name pslogging
```

> Add a table to a Log Analytics Workspace

```powershell
Get-EalaWorkspace -Subscription "Fred's Test Subscription" -ResourceGroup rg_scripting -Name pslogging | New-EalaTable -Name entra_scripting -Plan Analytics -ColumnTemplate PSFrameworkLog -RetentionInDays 21 -Description 'Central Log for Entra-Automation, monitored for error events'
```

> Create a Data Collection Rule

```powershell
New-EalaDataCollectionRule -Subscription "Fred's Test Subscription" -ResourceGroup rg_scripting -WorkspaceName pslogging -Name EntraPSIngestion
```

### Setting Everythingg up for PSFramework Logging

Setting everything up so a PowerShell script can log to a Log Analytics table can be burdensome.
So here is the full setup displayed:

1. Authenticate
2. Create Resource Group
3. Create Workspace
4. Create Table
5. Create Data Collection Rule that points at the Workspace
6. Create Data Collection Endpoint that data is sent through
7. Grant Access to DCR for app/user supposed to write logs

```powershell
# 0: Defines
$subscription = 'e2b198e0-a309-4c91-b53e-4e36184bce9a'
$rgName = 'rg_demo'
$laWorkspace = 'pslogging'
$laTable = 'entra_scripting'
$location = 'westeurope'

# 1: Connect
Connect-EntraService -Service Azure -ClientID Azure
Connect-EntraService -Service Graph -ClientID Azure -UseRefreshToken

# 2: Create Resource Group
$resourceGroup = New-EaaResourceGroup -Subscription $subscription -Name $rgName -Location $location

# 3: Create Workspace
$workspace = New-EalaWorkspace -Subscription $subscription -ResourceGroup $resourceGroup.Name -Name $laWorkspace

# 4: Create Table
$workspace | New-EalaTable -Name $laTable -Plan Analytics -ColumnTemplate PSFrameworkLog -RetentionInDays 21 -Description 'Central Log for Entra-Automation, monitored for error events'

# 5: Create Data Collection Endpoint
$dataCollectionEndpoint = $workspace | New-EalaDataCollectionEndpoint -Name ("$($laWorkspace)-$($laTable)-DCE" -replace '_','-')

# 6: Create Data Collection Rule
$dataCollectionRule = $workspace | New-EalaDataCollectionRule -TableName $laTable -Name "$($laWorkspace)-$($laTable)-DCR" -EndpointID $dataCollectionEndpoint.id

# 7: Authorize Users or Applications
New-EaaRoleAssignment -ResourceID $dataCollectionRule.id -RoleName 'Monitoring Metrics Publisher' -PrincipalID 'fred@contoso.com' -PrincipalType User -Description 'Because'
New-EaaRoleAssignment -ResourceID $dataCollectionRule.id -RoleName 'Monitoring Metrics Publisher' -PrincipalID 'Entra - PowerShell Script Logging' -PrincipalType ServicePrincipal -Description 'Scripts need it'
```

> Note: The only thing PSFramework specific are the table settings in Step 4. This is where you define the ultimate structure of the log.

### Sending Data

> Note: This assumes you created the structure with the snippet above

```powershell
# 0: Defines
$subscription = 'e2b198e0-a309-4c91-b53e-4e36184bce9a'
$rgName = 'rg_demo'
$laWorkspace = 'pslogging'
$laTable = 'entra_scripting'
$dcrName = "$($laWorkspace)-$($laTable)-DCR"
$dceName = "$($laWorkspace)-$($laTable)-DCE" -replace '_','-'

# 1: Connect
Connect-EntraService -Service Azure -ClientID Azure

# 2: Send Data
Write-EalaTableEntry -Subscription $subscription -DcrName $dcrName -DceName $dceName -Message (Get-PSFMessage)
```
