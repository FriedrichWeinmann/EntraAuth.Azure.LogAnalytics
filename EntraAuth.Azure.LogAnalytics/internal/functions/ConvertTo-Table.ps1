function ConvertTo-Table {
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
			
			Object               = $InputObject
		}
	}
}