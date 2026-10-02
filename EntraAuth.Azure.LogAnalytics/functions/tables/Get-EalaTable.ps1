function Get-EalaTable {
	<#
	.SYNOPSIS
		Retrieves tables from a Log Analytics workspace.

	.DESCRIPTION
		Retrieves Log Analytics tables and filters them by name.
		Unless Literal is specified, the filter also matches the custom-table _CL suffix.

	.PARAMETER Subscription
		The name or ID of the Azure subscription containing the workspace.

	.PARAMETER ResourceGroup
		The name of the resource group containing the workspace.

	.PARAMETER WorkspaceName
		The name of the Log Analytics workspace containing the tables.

	.PARAMETER Name
		The table name or wildcard pattern to retrieve.
		Defaults to: *

	.PARAMETER Literal
		Matches only the supplied table name pattern and disables automatic matching of the _CL custom-table suffix.

	.PARAMETER ServiceMap
		Optional hashtable to map service names to specific EntraAuth service instances.
		Used for advanced scenarios where you want to use something other than the default Azure connection.
		Example: @{ Azure = 'MyAzure' }
		This will switch all Azure API calls to use the configuration defined in MyAzure.
		Defaults to: @{}

	.EXAMPLE
		PS C:\> Get-EalaTable -Subscription 'Production' -ResourceGroup 'rg-monitoring' -WorkspaceName 'law-prod' -Name 'AppLogs'

		Retrieves tables matching AppLogs or AppLogs_CL from the specified workspace.

	.EXAMPLE
		PS C:\> Get-EalaWorkspace -Subscription 570b5874-4ced-4cc7-92ad-82308ccc7f93 -Name pslogging | Get-EalaTable -Name ps_*

		Retrieves all tables that start with "ps_" in the workspace "pslogging" under the specified subscription.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.Subscription')]
		[string]
		$Subscription,

		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.ResourceGroup')]
		[string]
		$ResourceGroup,

		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[PsfValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{2,61}[A-Za-z0-9]$', ErrorMessage = 'Invalid Name: {0}. Workspace names must be 4-63 characters long and only contain regular letters, numbers, and dashes.')]
		[string]
		$WorkspaceName,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string]
		$Name = '*',

		[switch]
		$Literal,

		[ServiceTransformAttribute()]
		[hashtable]
		$ServiceMap = @{}
	)
	begin {
		$services = $script:_serviceSelector.GetServiceMap($ServiceMap)
		Assert-EntraConnection -Cmdlet $PSCmdlet -Service $services.Azure
		$subCache = @{}
	}
	process {
		$subscriptionID = Resolve-Subscription -Name $Subscription -Services $services -Cache $subCache -Cmdlet $PSCmdlet

		Invoke-EntraRequest -Service $services.Azure -Path "subscriptions/$subscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/tables/" -Query @{
			'api-version' = '2026-03-01'
		} | ConvertTo-Table | Where-Object {
			$_.Name -like $Name -or
			(
				-not $Literal -and
				$_.Name -like "$($Name)_CL"
			)
		}
	}
}