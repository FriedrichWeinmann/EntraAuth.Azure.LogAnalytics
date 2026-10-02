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