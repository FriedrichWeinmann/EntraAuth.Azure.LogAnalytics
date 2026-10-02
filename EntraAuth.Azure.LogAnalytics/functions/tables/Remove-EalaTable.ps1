function Remove-EalaTable {
	<#
	.SYNOPSIS
		Removes a table from a Log Analytics workspace.

	.DESCRIPTION
		Deletes a table from a Log Analytics workspace.

	.PARAMETER Subscription
		The name or ID of the Azure subscription containing the workspace.

	.PARAMETER ResourceGroup
		The name of the resource group containing the workspace.

	.PARAMETER WorkspaceName
		The name of the Log Analytics workspace containing the table.

	.PARAMETER Name
		The name of the table to remove.

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
		PS C:\> Get-EalaTable -Subscription 'Test' -ResourceGroup 'rg-test' -WorkspaceName 'law-test' -Name 'TempData' | Remove-EalaTable

		Retrieves a table and removes it through the pipeline.
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
		$WorkspaceName,

		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[PsfValidatePattern('^[A-Za-z0-9-_]+$', ErrorMessage = 'Invalid Name: {0}. Table-names may only contain default letters of the 26-letter alphabet, numbers, dash and underscore')]
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

		Invoke-PSFProtectedCommand -Action "Deleting table $Name from $subscriptionID > $ResourceGroup > $WorkspaceName" -Target $Name -ScriptBlock {
			Invoke-EntraRequest -Service $services.Azure -Method DELETE -Path "subscriptions/$subscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/tables/$Name" -Query @{
				'api-version' = '2026-03-01'
			}
		} -EnableException $true -PSCmdlet $PSCmdlet
	}
}