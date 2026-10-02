function Remove-EalaWorkspace {
	<#
	.SYNOPSIS
		Removes a Log Analytics workspace.

	.DESCRIPTION
		Deletes a Log Analytics workspace from an Azure subscription and resource group.

	.PARAMETER Subscription
		The name or ID of the Azure subscription containing the workspace.

	.PARAMETER ResourceGroup
		The name of the resource group containing the workspace.

	.PARAMETER Name
		The name of the Log Analytics workspace to remove.

	.PARAMETER Force
		Request forced deletion.

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
		PS C:\> Remove-EalaWorkspace -Subscription 'Test' -ResourceGroup 'rg-test' -Name 'law-old' -Force

		Forces deletion of the specified Log Analytics workspace.
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

		[switch]
		$Force,

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
		$query = @{
			'api-version' = '2026-03-01'
		}
		if ($Force) { $query.force = $true }

		Invoke-PSFProtectedCommand -Action "Deleting Azure Log Analytics Workspace $Name in $SubscriptionID/$ResourceGroup" -Target $Name -ScriptBlock {
			$null = Invoke-EntraRequest -Service $services.Azure -Method Delete -Path "subscriptions/$subscriptionID/resourcegroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$Name" -Query $query
		} -PSCmdlet $PSCmdlet -EnableException $true
	}
}