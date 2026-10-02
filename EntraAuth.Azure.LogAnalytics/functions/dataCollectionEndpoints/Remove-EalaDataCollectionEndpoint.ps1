function Remove-EalaDataCollectionEndpoint {
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
		[string]
		$Name,

		[ServiceTransformAttribute()]
		[hashtable]
		$ServiceMap = @{}
	)
	begin {
		$services = $script:_serviceSelector.GetServiceMap($ServiceMap)
		Assert-EntraConnection -Cmdlet $PSCmdlet -Service $services.Azure
	}
	process {
		$subscriptionID = Resolve-Subscription -Name $Subscription -Services $services -Cmdlet $PSCmdlet

		Invoke-PSFProtectedCommand -Action "Deleting Data Collection Endpoint $Name in $subscriptionID > $ResourceGroup" -Target $Name -ScriptBlock {
			Invoke-EntraRequest -Service $services.Azure -Method DELETE -Path "subscriptions/$subscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionEndpoints/$Name" -Query @{
				'api-version' = '2024-03-11'
			}
		} -EnableException $true -PSCmdlet $PSCmdlet
	}
}