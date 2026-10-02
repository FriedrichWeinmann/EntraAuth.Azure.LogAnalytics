function ConvertTo-Workspace {
	<#
	.SYNOPSIS
		Converts an Azure workspace resource to a module workspace object.

	.DESCRIPTION
		Transforms a raw Azure Log Analytics workspace resource into an EntraAuth.Azure.LogAnalytics.Workspace object with normalized subscription, resource group, status, timestamps, and source-object properties.

	.PARAMETER InputObject
		The raw Azure Log Analytics workspace resource to convert. Null input produces no output.

	.EXAMPLE
		PS C:\> $workspaceResource | ConvertTo-Workspace

		Converts a raw Azure workspace resource returned by the Azure API into the module's standard workspace object.
	#>
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline = $true)]
		$InputObject
	)
	process {
		if (-not $InputObject) { return }

		[PSCustomObject]@{
			PSTypeName    = 'EntraAuth.Azure.LogAnalytics.Workspace'
			Subscription  = ($InputObject.id -split '/')[2]
			ResourceGroup = ($InputObject.id -split '/')[4]
			Name          = $InputObject.name
			ID            = $InputObject.id
			Location      = $InputObject.location
			Status        = $InputObject.properties.provisioningState
			Tags          = $InputObject.tags
			Created       = $InputObject.properties.createdDate
			Modified      = $InputObject.properties.modifiedDate
			Properties    = $InputObject.properties

			# For commands taking a workspace by pipeline
			WorkspaceName = $InputObject.name
			
			Object        = $InputObject
		}
	}
}