function Set-EalaWorkspace {
	<#
	.SYNOPSIS
		Updates a Log Analytics workspace.

	.DESCRIPTION
		Updates tags, identity, retention, SKU, features, replication, or custom properties on an existing Log Analytics workspace. At least one setting must be specified.

	.PARAMETER Subscription
		The name or ID of the Azure subscription containing the workspace.

	.PARAMETER ResourceGroup
		The name of the resource group containing the workspace.

	.PARAMETER Name
		The name of the Log Analytics workspace to update.

	.PARAMETER Tags
		A hashtable of tags to apply to the workspace.

	.PARAMETER SystemIdentity
		Enables a system-assigned managed identity on the workspace.

	.PARAMETER RetentionDays
		The workspace data retention period in days.

	.PARAMETER Sku
		The pricing SKU to assign to the workspace.

	.PARAMETER EnableFeatures
		One or more WorkspaceFeatures flags to enable.

	.PARAMETER DisableFeatures
		One or more WorkspaceFeatures flags to disable.

	.PARAMETER ReplicationLocation
		The secondary Azure region in which to enable workspace replication.

	.PARAMETER DisableReplication
		Disables replication for the workspace.

	.PARAMETER Properties
		A hashtable of additional workspace properties to update.

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
		PS C:\> Set-EalaWorkspace -Subscription 'Production' -ResourceGroup 'rg-monitoring' -Name 'law-prod' -RetentionDays 180 -EnableFeatures EnableDataExport -ReplicationLocation 'westus'

		Sets retention to 180 days, enables data export, and configures replication to westus.
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
		[PsfValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{2,61}[A-Za-z0-9]$', ErrorMessage = 'Invalid Name: {0}. Workspace names must be 4-63 characters long and only contain regular letters, numbers, and dashes.')]
		[string]
		$Name,

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

		[Alias('Features')]
		[WorkspaceFeatures]
		$EnableFeatures,

		[WorkspaceFeatures]
		$DisableFeatures,

		[string]
		$ReplicationLocation,

		[switch]
		$DisableReplication,

		[hashtable]
		$Properties,

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

		$body = @{}

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
		
		$features = @{ }
		if ($PSBoundParameters.Keys -contains 'EnableFeatures') {
			if ($EnableFeatures -band [WorkspaceFeatures]::DataAuthorizationMode) { $features['dataAuthorizationMode'] = $true }
			if ($EnableFeatures -band [WorkspaceFeatures]::DisableLocalAuth) { $features['disableLocalAuth'] = $true }
			if ($EnableFeatures -band [WorkspaceFeatures]::EnableDataExport) { $features['enableDataExport'] = $true }
			if ($EnableFeatures -band [WorkspaceFeatures]::OnlyResourceAccess) { $features['enableLogAccessUsingOnlyResourcePermissions'] = $true }
			if ($EnableFeatures -band [WorkspaceFeatures]::ImmediateDataPurge) { $features['immediatePurgeDataOn30Days'] = $true }
		}
		if ($PSBoundParameters.Keys -contains 'DisableFeatures') {
			if ($DisableFeatures -band [WorkspaceFeatures]::DataAuthorizationMode) { $features['dataAuthorizationMode'] = $false }
			if ($DisableFeatures -band [WorkspaceFeatures]::DisableLocalAuth) { $features['disableLocalAuth'] = $false }
			if ($DisableFeatures -band [WorkspaceFeatures]::EnableDataExport) { $features['enableDataExport'] = $false }
			if ($DisableFeatures -band [WorkspaceFeatures]::OnlyResourceAccess) { $features['enableLogAccessUsingOnlyResourcePermissions'] = $false }
			if ($DisableFeatures -band [WorkspaceFeatures]::ImmediateDataPurge) { $features['immediatePurgeDataOn30Days'] = $false }
		}
		if ($features.Count -gt 0) { $propertySet['features'] = $features }

		if ($ReplicationLocation) {
			$propertySet.replication = @{
				enabled  = $true
				location = $ReplicationLocation
			}
		}
		if ($DisableReplication) {
			$propertySet.replication = @{
				enabled = $false
			}
		}
		if ($propertySet.Count -gt 0) { $body.properties = $propertySet }

		if ($body.Count -lt 1) {
			Write-Error 'No changes specified, nothing to do!'
			return
		}

		Invoke-PSFProtectedCommand -Action "Creating Azure Log Analytics Workspace $Name in $SubscriptionID/$ResourceGroup" -Target $Name -ScriptBlock {
			Invoke-EntraRequest -Service $services.Azure -Method PATCH -Path "subscriptions/$subscriptionID/resourcegroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$Name" -Query @{
				'api-version' = '2026-03-01'
			} -Body $body -ContentType 'application/json' | ConvertTo-Workspace
		} -EnableException $true -PSCmdlet $PSCmdlet
	}
}