function ConvertTo-Endpoint {
	<#
	.SYNOPSIS
		Converts an Azure data collection endpoint resource to a module endpoint object.

	.DESCRIPTION
		Transforms a raw Azure Monitor data collection endpoint resource into an EntraAuth.Azure.LogAnalytics.DataCollectionEndpoint object with normalized resource, ingestion link, status, timestamp, and source-object properties.

	.PARAMETER InputObject
		The raw Azure Monitor data collection endpoint resource to convert. Null input produces no output.

	.EXAMPLE
		PS C:\> $endpointResource | ConvertTo-Endpoint

		Converts a raw Azure data collection endpoint resource into the module's standard endpoint object.
	#>
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