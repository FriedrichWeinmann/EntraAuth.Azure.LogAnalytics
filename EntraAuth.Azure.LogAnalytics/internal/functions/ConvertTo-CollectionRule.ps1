function ConvertTo-CollectionRule {
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline = $true)]
		$InputObject
	)
	process {
		if (-not $InputObject) { return }

		$streams = @{}
		foreach ($streamName in $InputObject.properties.streamDeclarations.PSObject.Properties.Name) {
			$streams[$streamName] = [PSCustomObject]@{
				Name     = $streamName
				Colummns = $InputObject.properties.streamDeclarations.$streamName.columns
				Object   = $InputObject.properties.streamDeclarations.$streamName
			}
		}

		[PSCustomObject]@{
			PSTypeName         = 'EntraAuth.Azure.LogAnalytics.DataCollectionRule'
			Subscription       = ($InputObject.id -split '/')[2]
			ResourceGroup      = ($InputObject.id -split '/')[4]
			Name               = $InputObject.name
			ID                 = $InputObject.id
			Location           = $InputObject.location

			Streams            = $streams
			DataSources        = $InputObject.properties.dataSources
			Destinations       = $InputObject.properties.destinations
			DataFlows          = $InputObject.properties.dataFlows
			EndpointName       = $InputObject.properties.dataCollectionEndpointId -replace '^.+/'
			EndpointID         = $InputObject.properties.dataCollectionEndpointId

			ImmutableID        = $InputObject.properties.immutableId
			Status             = $InputObject.properties.provisioningState
			Tags               = $InputObject.tags
			Created            = $InputObject.systemData.createdAt
			Modified           = $InputObject.systemData.lastModifiedAt
			Properties         = $InputObject.properties

			CollectionRuleName = $InputObject.name
			
			Object             = $InputObject
		}
	}
}