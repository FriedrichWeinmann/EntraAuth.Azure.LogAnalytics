function Get-EalaDataCollectionEndpoint {
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
	}
	process {
		$subscriptionID = Resolve-Subscription -Name $Subscription -Services $services -Cmdlet $PSCmdlet

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