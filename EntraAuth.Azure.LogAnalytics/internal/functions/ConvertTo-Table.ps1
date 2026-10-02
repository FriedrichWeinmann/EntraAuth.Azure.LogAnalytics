function ConvertTo-Table {
	<#
	.SYNOPSIS
		Converts an Azure table resource to a module table object.

	.DESCRIPTION
		Transforms a raw Azure Log Analytics table resource into an EntraAuth.Azure.LogAnalytics.Table object with normalized subscription, resource group, workspace, schema, retention, and source-object properties.

	.PARAMETER InputObject
		The raw Azure Log Analytics table resource to convert. Null input produces no output.

	.EXAMPLE
		PS C:\> $tableResource | ConvertTo-Table

		Converts a raw Azure table resource returned by the Azure API into the module's standard table object.
	#>
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline = $true)]
		$InputObject
	)
	process {
		if (-not $InputObject) { return }

		[PSCustomObject]@{
			PSTypeName           = 'EntraAuth.Azure.LogAnalytics.Table'
			Subscription         = ($InputObject.id -split '/')[2]
			ResourceGroup        = ($InputObject.id -split '/')[4]
			WorkspaceName        = ($InputObject.id -split '/')[8]
			Name                 = $InputObject.name
			DisplayName          = $InputObject.properties.schema.displayName
			Description          = $InputObject.properties.schema.description
			ID                   = $InputObject.id
			Plan                 = $InputObject.properties.plan
			ProtectionLevel      = $InputObject.properties.protectionLevel
			RetentionInDays      = $InputObject.properties.retentionInDays
			TotalRetentionInDays = $InputObject.properties.totalRetentionInDays
			Solutions            = $InputObject.properties.schema.solutions
			Columns              = $InputObject.properties.schema.columns
			ProvisioningState    = $InputObject.properties.provisioningState
			
			Properties           = $InputObject.properties
			
			TableName            = $InputObject.name
			Object               = $InputObject
		}
	}
}