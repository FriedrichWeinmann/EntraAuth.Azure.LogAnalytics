function Remove-EalaDataCollectionEndpoint {
	<#
	.SYNOPSIS
		Removes an Azure Monitor data collection endpoint.

	.DESCRIPTION
		Deletes a data collection endpoint from an Azure subscription and resource group. Endpoint objects can be supplied through the pipeline by property name.

	.PARAMETER Subscription
		The name or ID of the Azure subscription containing the endpoint.

	.PARAMETER ResourceGroup
		The name of the resource group containing the endpoint.

	.PARAMETER Name
		The name of the data collection endpoint to remove.

	.PARAMETER ServiceMap
		Optional hashtable to map service names to specific EntraAuth service instances.
		Used for advanced scenarios where you want to use something other than the default Azure connection.
		Example: @{ Azure = 'MyAzure' }
		This will switch all Azure API calls to use the configuration defined in MyAzure.
		Defaults to: @{}

	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

	.EXAMPLE
		PS C:\> Get-EalaDataCollectionEndpoint -Subscription 'Test' -ResourceGroup 'rg-test' -Name 'dce-old' | Remove-EalaDataCollectionEndpoint

		Retrieves a data collection endpoint and removes it through the pipeline.
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.Subscription')]
		[Alias('SubscriptionID')]
		[string]
		$Subscription,
		
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.ResourceGroup')]
		[string]
		$ResourceGroup,
		
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
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

		Invoke-PSFProtectedCommand -Action "Deleting Data Collection Endpoint $Name in $subscriptionID > $ResourceGroup" -Target $Name -ScriptBlock {
			Invoke-EntraRequest -Service $services.Azure -Method DELETE -Path "subscriptions/$subscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionEndpoints/$Name" -Query @{
				'api-version' = '2024-03-11'
			}
		} -EnableException $true -PSCmdlet $PSCmdlet
	}
}