Register-PSFTeppScriptblock -Name 'EntraAuth.Azure.LogAnalytics.Sku' -ScriptBlock {
	'Free', 'Standard', 'Premium', 'PerNode', 'PerGB2018', 'Standalone', 'CapacityReservation', 'LACluster'
}

Register-PSFTeppScriptblock -Name 'EntraAuth.Azure.LogAnalytics.TableColumnTemplate' -ScriptBlock {
	Get-EalaColumnTemplate | ForEach-Object {
		@{
			Text    = $_.Name
			Tooltip = $_.Description
		}
	}
}

Register-PSFTeppScriptblock -Name 'EntraAuth.Azure.LogAnalytics.DataCollectionEndpoint' -ScriptBlock {
	if (-not $fakeBoundParameter.Subscription) { return }
	$param = @{ Subscription = $fakeBoundParameter.Subscription }
	if ($fakeBoundParameter.ResourceGroup) { $param.ResourceGroup = $fakeBoundParameter.ResourceGroup }

	Get-EalaDataCollectionEndpoint @param | ForEach-Object {
		@{
			Text    = $_.Name
			Tooltip = '{0} > {1} > {2} ({3})' -f $_.Subscription, $_.ResourceGroup, $_.Name, $_.Location
		}
	}
}
Register-PSFTeppScriptblock -Name 'EntraAuth.Azure.LogAnalytics.DataCollectionRule' -ScriptBlock {
	if (-not $fakeBoundParameter.Subscription) { return }
	$param = @{ Subscription = $fakeBoundParameter.Subscription }
	if ($fakeBoundParameter.ResourceGroup) { $param.ResourceGroup = $fakeBoundParameter.ResourceGroup }

	Get-EalaDataCollectionRule @param | ForEach-Object {
		@{
			Text    = $_.Name
			Tooltip = '{0} > {1} > {2} ({3})' -f $_.Subscription, $_.ResourceGroup, $_.Name, $_.Location
		}
	}
}