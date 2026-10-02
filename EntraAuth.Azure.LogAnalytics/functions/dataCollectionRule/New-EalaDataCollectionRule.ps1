function New-EalaDataCollectionRule {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.Subscription')]
		[string]
		$Subscription,

		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.ResourceGroup')]
		[string]
		$ResourceGroup,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[PsfValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{2,61}[A-Za-z0-9]$', ErrorMessage = 'Invalid Name: {0}. Workspace names must be 4-63 characters long and only contain regular letters, numbers, and dashes.')]
		[string]
		$WorkspaceName,
		
		[Parameter(Mandatory = $true)]
		[string]
		$Name,
		
		[string]
		$Location,

		[hashtable]
		$Tags,

		[ValidateSet('Windows', 'Linux')]
		[string]
		$Kind,

		[switch]
		$SystemIdentity,

		[hashtable]
		$Destinations,

		[string]
		$EndpointID,

		[hashtable[]]
		$DataFlows,

		[hashtable]
		$DataSources,

		[hashtable]
		$DirectDataSources,

		[hashtable]
		$References,

		[hashtable]
		$AgentSettings,

		[hashtable]
		$Sku,

		[ServiceTransformAttribute()]
		[hashtable]
		$ServiceMap = @{}
	)
	begin {
		$services = $script:_serviceSelector.GetServiceMap($ServiceMap)
		Assert-EntraConnection -Cmdlet $PSCmdlet -Service $services.Azure

		# https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create
	}
	process {
		$subscriptionID = Resolve-Subscription -Name $Subscription -Services $services -Cmdlet $PSCmdlet

		$actualLocation = $Location
		if (-not $actualLocation) {
			$actualLocation = (Get-EaaResourceGroup -ServiceMap $services -Subscription $subscriptionID -Name $ResourceGroup).Location
		}

		$body = @{
			id         = "/subscriptions/$subscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/$Name"
			location   = $actualLocation
			type       = 'Microsoft.Insights/dataCollectionRules'
			name       = $Name
			properties = @{
				dataSources  = @{}
				destinations = @{
					logAnalytics = @()
				}
			}
		}

		if ($Destinations) {
			foreach ($key in $Destinations.Keys) {
				$body.properties.destinations[$key] = @($Destinations[$key])
			}
		}
		if ($DataSources) {
			foreach ($key in $DataSources.Keys) {
				$body.properties.dataSources[$key] = @($DataSources[$key])
			}
		}
		if ($DirectDataSources) {
			$body.properties.directDataSources = @{}
			foreach ($key in $DirectDataSources.Keys) {
				$body.properties.directDataSources[$key] = @($DirectDataSources[$key])
			}
		}
		if ($References) {
			$body.properties.references = $References
		}
		if ($DataFlows) {
			$body.properties.dataFlows = @($DataFlows)
		}
		if ($EndpointID) {
			$body.properties.dataCollectionEndpointId = $EndpointID
		}
		if ($Kind) {
			$body.kind = $Kind
		}
		if ($AgentSettings) {
			$body.agentSettings = $AgentSettings
		}
		if ($WorkspaceName) {
			$workspaceObject = Get-EalaWorkspace -Subscription $subscriptionID -ResourceGroup $ResourceGroup -Name $WorkspaceName -ServiceMap $services

			$body.properties.destinations.logAnalytics += @{
				workspaceResourceId = $workspaceObject.ID
				workspaceId         = $workspaceObject.Properties.customerId
				name                = $workspaceObject.Name
			}
		}
		if ($Tags) { $body.tags = $Tags }
		if ($Sku) { $body.sku = $Sku }
		if ($SystemIdentity) {
			$body.identity = @{
				tenantId = (Get-EntraToken -Service $services.Azure).TenantId
				type     = 'SystemAssigned'
			}
		}

		# PUT https://management.azure.com/subscriptions/fe923424-d71c-48fc-a446-29f295c1f08c/resourceGroups/rg_psframework/providers/Microsoft.Insights/dataCollectionRules/TestDCR?api-version=2023-03-11&ignoreMissingTables=true
		$param = @{
			Service     = $services.Azure
			Method      = 'PUT'
			Path        = "subscriptions/$subscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/$Name"
			ContentType = 'application/json'
			Query       = @{
				'api-version'       = '2024-03-11'
				ignoreMissingTables = $true
			} 
		}

		Invoke-PSFProtectedCommand -Action "Creating Data Collection Rule $Name in $subscriptionID > $ResourceGroup" -Target $Name -ScriptBlock {
			Invoke-EntraRequest @param -Body $body
		} -EnableException $true -PSCmdlet $PSCmdlet
	}
}