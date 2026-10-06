function Get-EalaDataCollectionRule {
	<#
	.SYNOPSIS
		Retrieves Azure Monitor data collection rules.

	.DESCRIPTION
		Retrieves data collection rules from an Azure subscription.
		Results can be scoped to a resource group and filtered by name with wildcard patterns.

	.PARAMETER Subscription
		The name or ID of the Azure subscription containing the data collection rules.

	.PARAMETER ResourceGroup
		The resource group containing the rules. When omitted, rules from all resource groups in the subscription are returned.

	.PARAMETER Name
		The rule name or wildcard pattern to retrieve. When omitted, all matching rules are returned.
		Defaults to: *

	.PARAMETER ServiceMap
		Optional hashtable to map service names to specific EntraAuth service instances.
		Used for advanced scenarios where you want to use something other than the default Azure connection.
		Example: @{ Azure = 'MyAzure' }
		This will switch all Azure API calls to use the configuration defined in MyAzure.
		Defaults to: @{}

	.EXAMPLE
		PS C:\> Get-EalaDataCollectionRule -Subscription 'Production' -ResourceGroup 'rg-monitoring' -Name 'dcr-app-*'

		Retrieves data collection rules whose names begin with dcr-app- from the specified resource group.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.Subscription')]
		[Alias('SubscriptionID')]
		[string]
		$Subscription,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.ResourceGroup')]
		[string]
		$ResourceGroup,
		
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
			Invoke-EntraRequest -Service $services.Azure -Path "subscriptions/$subscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/$Name" -Query @{
				'api-version' = '2024-03-11'
			} | ConvertTo-CollectionRule
			return
		}

		if (-not $Name) { $Name = '*' }

		$rgString = ''
		if ($ResourceGroup) { $rgString = "resourceGroups/$ResourceGroup/" }

		Invoke-EntraRequest -Service $services.Azure -Path "subscriptions/$subscriptionID/$($rgString)providers/Microsoft.Insights/dataCollectionRules" -Query @{
			'api-version' = '2024-03-11'
		} | Where-Object Name -Like $Name | ConvertTo-CollectionRule
	}
}