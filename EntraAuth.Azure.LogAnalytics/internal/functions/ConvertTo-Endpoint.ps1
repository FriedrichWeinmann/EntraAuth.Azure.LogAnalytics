function ConvertTo-Endpoint {
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline = $true)]
		$InputObject
	)
	process {
		if (-not $InputObject) { return }

		[PSCustomObject]@{
			PSTypeName        = 'EntraAuth.Azure.LogAnalytics.DataCollectionEndpoint'
			Subscription      = ($InputObject.id -split '/')[2]
			ResourceGroup     = ($InputObject.id -split '/')[4]
			Name              = $InputObject.name
			ID                = $InputObject.id
			Location          = $InputObject.location

			LinkIngestion     = $InputObject.properties.logsIngestion.endpoint
			LinkMetrics       = $InputObject.properties.metricsIngestion.endpoint
			LinkConfiguration = $InputObject.properties.configurationAccess.endpoint
			
			ImmutableID       = $InputObject.properties.immutableId
			PublicNetwork     = $InputObject.properties.networkAcls.publicNetworkAccess
			Status            = $InputObject.properties.provisioningState
			Tags              = $InputObject.tags
			Created           = $InputObject.systemData.createdAt
			Modified          = $InputObject.systemData.lastModifiedAt
			Properties        = $InputObject.properties

			EndpointName      = $InputObject.name
			
			Object            = $InputObject
		}
	}
}