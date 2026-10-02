function ConvertTo-Workspace {
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