function Get-EalaWorkspace {
	<#
	.SYNOPSIS
		Retrieves Log Analytics workspaces.

	.DESCRIPTION
		Retrieves Log Analytics workspaces from an Azure subscription.
		Results can be scoped to a resource group and filtered by workspace name.

	.PARAMETER Subscription
		The name or ID of the Azure subscription containing the workspaces.

	.PARAMETER ResourceGroup
		The resource group containing the workspaces. When omitted, workspaces from all resource groups in the subscription are returned.

	.PARAMETER Name
		The name of the workspace to retrieve. When omitted, all matching workspaces are returned.
		Defaults to: *

	.PARAMETER ID
		The full Azure Resource ID of the Workspace to retrieve.

	.PARAMETER ServiceMap
		Optional hashtable to map service names to specific EntraAuth service instances.
		Used for advanced scenarios where you want to use something other than the default Azure connection.
		Example: @{ Azure = 'MyAzure' }
		This will switch all Azure API calls to use the configuration defined in MyAzure.
		Defaults to: @{}

	.EXAMPLE
		PS C:\> Get-EalaWorkspace -Subscription 'Production' -ResourceGroup 'rg-monitoring' -Name 'law-prod'

		Retrieves the law-prod workspace from the specified resource group.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Search')]
		[PsfArgumentCompleter('EntraAuth.Azure.Subscription')]
		[Alias('SubscriptionID')]
		[string]
		$Subscription,
		
		[Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Search')]
		[PsfArgumentCompleter('EntraAuth.Azure.ResourceGroup')]
		[string]
		$ResourceGroup,
		
		[Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Search')]
		[PsfValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{2,61}[A-Za-z0-9]$', ErrorMessage = 'Invalid Name: {0}. Workspace names must be 4-63 characters long and only contain regular letters, numbers, and dashes.')]
		[string]
		$Name,

		[Parameter(Mandatory = $true, ParameterSetName = 'ByID')]
		$ID,

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
		if ($ID) {
			Invoke-EntraRequest -Service $services.Azure -Path $ID -Query @{
				'api-version' = '2026-03-01'
			} | ConvertTo-Workspace
			return
		}

		$subscriptionID = Resolve-Subscription -Name $Subscription -Services $services -Cache $subCache -Cmdlet $PSCmdlet
		$rgString = ''
		if ($ResourceGroup) { $rgString = "resourcegroups/$ResourceGroup/" }
		
		if ($Name -and $ResourceGroup) {
			Invoke-EntraRequest -Service $services.Azure -Path "subscriptions/$subscriptionID/$($rgString)providers/Microsoft.OperationalInsights/workspaces/$Name" -Query @{
				'api-version' = '2026-03-01'
			} | ConvertTo-Workspace
			return
		}
		$nameFilter = '*'
		if ($Name) { $nameFilter = $Name }
		
		Invoke-EntraRequest -Service $services.Azure -Path "subscriptions/$subscriptionID/$($rgString)providers/Microsoft.OperationalInsights/workspaces" -Query @{
			'api-version' = '2026-03-01'
		} | ConvertTo-Workspace | Where-Object Name -Like $nameFilter
	}
}