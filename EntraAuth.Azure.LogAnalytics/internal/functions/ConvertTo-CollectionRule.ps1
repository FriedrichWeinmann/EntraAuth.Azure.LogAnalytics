function ConvertTo-CollectionRule {
	<#
	.SYNOPSIS
		Converts an Azure data collection rule resource to a module collection rule object.

	.DESCRIPTION
		Transforms a raw Azure Monitor data collection rule resource into an EntraAuth.Azure.LogAnalytics.DataCollectionRule object with normalized streams, destinations, data flows, status, timestamps, and source-object properties.

	.PARAMETER InputObject
		The raw Azure Monitor data collection rule resource to convert. Null input produces no output.

	.EXAMPLE
		PS C:\> $ruleResource | ConvertTo-CollectionRule

		Converts a raw Azure data collection rule resource into the module's standard collection rule object.
	#>
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
				Name    = $streamName
				Columns = $InputObject.properties.streamDeclarations.$streamName.columns
				Object  = $InputObject.properties.streamDeclarations.$streamName
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