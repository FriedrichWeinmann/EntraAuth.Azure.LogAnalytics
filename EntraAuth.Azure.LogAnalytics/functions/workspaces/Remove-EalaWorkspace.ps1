function Remove-EalaWorkspace {
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
		[PsfValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{2,61}[A-Za-z0-9]$', ErrorMessage = 'Invalid Name: {0}. Workspace names must be 4-63 characters long and only contain regular letters, numbers, and dashes.')]
		[string]
		$Name,

		[switch]
		$Force,

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
		$query = @{
			'api-version' = '2026-03-01'
		}
		if ($Force) { $query.force = $true }

		Invoke-PSFProtectedCommand -Action "Deleting Azure Log Analytics Workspace $Name in $SubscriptionID/$ResourceGroup" -Target $Name -ScriptBlock {
			$null = Invoke-EntraRequest -Service $services.Azure -Method Delete -Path "subscriptions/$subscriptionID/resourcegroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$Name" -Query $query
		}
	}
}