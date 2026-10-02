function Get-EalaDataCollectionEndpoint {
	<#
	.SYNOPSIS
		Retrieves Azure Monitor data collection endpoints.

	.DESCRIPTION
		Retrieves data collection endpoints from an Azure subscription. Results can be scoped to a resource group and filtered by name with wildcard patterns.

	.PARAMETER Subscription
		The name or ID of the Azure subscription containing the data collection endpoints.

	.PARAMETER ResourceGroup
		The resource group containing the data collection endpoints. When omitted, endpoints from all resource groups in the subscription are returned.

	.PARAMETER Name
		The endpoint name or wildcard pattern to retrieve. When omitted, all matching endpoints are returned.
		Defaults to: *

	.PARAMETER ServiceMap
		Optional hashtable to map service names to specific EntraAuth service instances.
		Used for advanced scenarios where you want to use something other than the default Azure connection.
		Example: @{ Azure = 'MyAzure' }
		This will switch all Azure API calls to use the configuration defined in MyAzure.
		Defaults to: @{}

	.EXAMPLE
		PS C:\> Get-EalaDataCollectionEndpoint -Subscription 'Production' -ResourceGroup 'rg-monitoring' -Name 'dce-*'

		Retrieves all data collection endpoints whose names begin with dce- from the specified resource group.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.Subscription')]
		[string]
		$Subscription,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.ResourceGroup')]
		[string]
		$ResourceGroup,
		
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string]
		$Name,

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

		if ($Name -and $Name -notmatch '\*' -and $ResourceGroup) {
			Invoke-EntraRequest -Service $services.Azure -Path "subscriptions/$subscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionEndpoints/$Name" -Query @{
				'api-version' = '2024-03-11'
			}
			return
		}

		if (-not $Name) { $Name = '*' }

		$rgString = ''
		if ($ResourceGroup) { $rgString = "resourceGroups/$ResourceGroup/" }

		Invoke-EntraRequest -Service $services.Azure -Path "subscriptions/$subscriptionID/$($rgString)providers/Microsoft.Insights/dataCollectionEndpoints" -Query @{
			'api-version' = '2024-03-11'
		} | Where-Object Name -Like $Name
	}
}