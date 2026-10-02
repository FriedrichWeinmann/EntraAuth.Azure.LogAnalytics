function Remove-EalaDataCollectionRule {
	<#
	.SYNOPSIS
		Removes an Azure Monitor data collection rule.

	.DESCRIPTION
		Deletes a data collection rule from an Azure subscription and resource group.

	.PARAMETER Subscription
		The name or ID of the Azure subscription containing the rule.

	.PARAMETER ResourceGroup
		The name of the resource group containing the rule.

	.PARAMETER Name
		The name of the data collection rule to remove.

	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

	.PARAMETER ServiceMap
		Optional hashtable to map service names to specific EntraAuth service instances.
		Used for advanced scenarios where you want to use something other than the default Azure connection.
		Example: @{ Azure = 'MyAzure' }
		This will switch all Azure API calls to use the configuration defined in MyAzure.
		Defaults to: @{}

	.EXAMPLE
		PS C:\> Get-EalaDataCollectionRule -Subscription 'Test' -ResourceGroup 'rg-test' -Name 'dcr-old' | Remove-EalaDataCollectionRule

		Retrieves a data collection rule and removes it through the pipeline.
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
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

		Invoke-PSFProtectedCommand -Action "Deleting Data Collection Rule $Name in $subscriptionID > $ResourceGroup" -Target $Name -ScriptBlock {
			Invoke-EntraRequest -Service $services.Azure -Method DELETE -Path "subscriptions/$subscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/$Name" -Query @{
				'api-version' = '2024-03-11'
			}
		} -EnableException $true -PSCmdlet $PSCmdlet
	}
}