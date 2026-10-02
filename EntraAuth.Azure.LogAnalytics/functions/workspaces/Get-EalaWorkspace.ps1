function Get-EalaWorkspace {
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
		[PsfValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{2,61}[A-Za-z0-9]$', ErrorMessage = 'Invalid Name: {0}. Workspace names must be 4-63 characters long and only contain regular letters, numbers, and dashes.')]
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