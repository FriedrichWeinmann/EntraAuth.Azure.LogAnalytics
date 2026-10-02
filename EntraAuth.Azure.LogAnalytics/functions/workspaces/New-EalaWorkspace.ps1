function New-EalaWorkspace {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.Subscription')]
		[string]
		$Subscription,

		[Parameter(Mandatory = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.ResourceGroup')]
		[string]
		$ResourceGroup,

		[Parameter(Mandatory = $true)]
		[PsfValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{2,61}[A-Za-z0-9]$', ErrorMessage = 'Invalid Name: {0}. Workspace names must be 4-63 characters long and only contain regular letters, numbers, and dashes.')]
		[string]
		$Name,

		[Parameter(Mandatory = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.Location')]
		[string]
		$Location,

		[string]
		$Etag,

		[hashtable]
		$Tags,

		[switch]
		$SystemIdentity,

		[Alias('retentionInDays')]
		[int]
		$RetentionDays,

		[PsfArgumentCompleter('EntraAuth.Azure.LogAnalytics.Sku')]
		[string]
		$Sku,

		[WorkspaceFeatures]
		$Features,

		[string]
		$ReplicationLocation,

		[hashtable]
		$Properties,

		[ServiceTransformAttribute()]
		[hashtable]
		$ServiceMap = @{}
	)
	begin {
		$services = $script:_serviceSelector.GetServiceMap($ServiceMap)
		Assert-EntraConnection -Cmdlet $PSCmdlet -Service $services.Azure
		$subscriptionID = Resolve-Subscription -Name $Subscription -Services $services -Cmdlet $PSCmdlet
	}
	process {
		$body = @{
			location = $Location
		}
		if ($Etag) { $body.etag = $Etag }
		if ($SystemIdentity) {
			$body.identity = @{
				tenantId = (Get-EntraToken -Service $services.Azure).TenantId
				type     = 'SystemAssigned'
			}
		}
		if ($Tags) { $body.tags = $Tags }

		$propertySet = @{}
		foreach ($key in $Properties.Keys) {
			$propertySet[$key] = $Properties[$key]
		}
		if ($PSBoundParameters.Keys -contains 'RetentionDays') { $propertySet['retentionInDays'] = $RetentionDays }
		if ($PSBoundParameters.Keys -contains 'Sku') { $propertySet['sku'] = @{ name = $Sku } }
		if ($PSBoundParameters.Keys -contains 'Features') {
			$propertySet['features'] = @{ }
			if ($Features -band [WorkspaceFeatures]::DataAuthorizationMode) { $propertySet['features']['dataAuthorizationMode'] = $true }
			if ($Features -band [WorkspaceFeatures]::DisableLocalAuth) { $propertySet['features']['disableLocalAuth'] = $true }
			if ($Features -band [WorkspaceFeatures]::EnableDataExport) { $propertySet['features']['enableDataExport'] = $true }
			if ($Features -band [WorkspaceFeatures]::OnlyResourceAccess) { $propertySet['features']['enableLogAccessUsingOnlyResourcePermissions'] = $true }
			if ($Features -band [WorkspaceFeatures]::ImmediateDataPurge) { $propertySet['features']['immediatePurgeDataOn30Days'] = $true }
		}
		if ($ReplicationLocation) {
			$propertySet.replication = @{
				enabled  = $true
				location = $ReplicationLocation
			}
		}
		$body.properties = $propertySet

		Invoke-PSFProtectedCommand -Action "Creating Azure Log Analytics Workspace $Name in $SubscriptionID/$ResourceGroup" -Target $Name -ScriptBlock {
			Invoke-EntraRequest -Service $services.Azure -Method PUT -Path "subscriptions/$subscriptionID/resourcegroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$Name" -Query @{
				'api-version' = '2026-03-01'
			} -Body $body -ContentType 'application/json' | ConvertTo-Workspace
		} -EnableException $true -PSCmdlet $PSCmdlet
	}
}