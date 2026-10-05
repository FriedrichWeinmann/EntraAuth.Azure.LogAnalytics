function New-EalaDataCollectionRule {
	<#
	.SYNOPSIS
		Creates an Azure Monitor data collection rule.

	.DESCRIPTION
		Creates a data collection rule with configurable data sources, destinations, data flows, references, agent settings, identity, and SKU.
		A Log Analytics workspace can be added automatically as a destination.

	.PARAMETER Subscription
		The name or ID of the target Azure subscription.

	.PARAMETER ResourceGroup
		The name of the resource group in which to create the rule.

	.PARAMETER WorkspaceName
		The name of a Log Analytics workspace to add as a destination.

	.PARAMETER TableName
		The name of the table the DCR should send data to.
		Will be ignored if no WorkspaceName is provided.

	.PARAMETER Name
		The name of the data collection rule to create.

	.PARAMETER Location
		The Azure region in which to create the rule.
		Defaults to: Location of the Resource Group

	.PARAMETER Tags
		A hashtable of tags to assign to the rule.

	.PARAMETER Kind
		The operating system kind associated with the rule. Valid values are Windows and Linux.

	.PARAMETER SystemIdentity
		Enables a system-assigned managed identity on the rule.

	.PARAMETER Destinations
		A hashtable defining destinations for collected data.
		Example:
		@{
			logAnalytics = @(
				@{
					name = 'MyWorkspace'
					workspaceId = 'bcff068b-18e7-4105-be9c-caba3bea59ce'
					workspaceResourceId = '16df342b-f30f-4103-986b-12a2feea9992'
				}
			)
		}
		https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create?view=rest-monitor-2024-03-11&tabs=HTTP#datacollectionruledestinations

	.PARAMETER EndpointID
		The Azure resource ID of the data collection endpoint to associate with the rule.

	.PARAMETER DataFlows
		An array of hashtables that map data streams to destinations and transformations.
		https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create?view=rest-monitor-2024-03-11&tabs=HTTP#dataflow

	.PARAMETER DataSources
		A hashtable defining the data sources collected by the rule.
		https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create?view=rest-monitor-2024-03-11&tabs=HTTP#datacollectionruledatasources

	.PARAMETER DirectDataSources
		A hashtable defining direct data sources for the rule.
		https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create?view=rest-monitor-2024-03-11&tabs=HTTP#datacollectionruledirectdatasources

	.PARAMETER References
		A hashtable defining reference data used by the rule.
		https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create?view=rest-monitor-2024-03-11&tabs=HTTP#datacollectionrulereferences

	.PARAMETER AgentSettings
		A hashtable defining settings for agents that use the rule.
		https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create?view=rest-monitor-2024-03-11&tabs=HTTP#datacollectionruleagentsettings

	.PARAMETER Sku
		A hashtable defining the rule SKU.
		https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create?view=rest-monitor-2024-03-11&tabs=HTTP#datacollectionruleresourcesku

	.PARAMETER FilePatterns
		What File Patterns to look for on a Monitoring Agent.
		Has no effect on messages/data sent directly, such as through the Write-EalaTableEntry command.
		Defaults to: C:\Test.json

	.PARAMETER ServiceMap
		Optional hashtable to map service names to specific EntraAuth service instances.
		Used for advanced scenarios where you want to use something other than the default Azure connection.
		Example: @{ Azure = 'MyAzure' }
		This will switch all Azure API calls to use the configuration defined in MyAzure.
		Defaults to: @{}
	
	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

	.EXAMPLE
		PS C:\> New-EalaDataCollectionRule -Subscription 'Production' -ResourceGroup 'rg-monitoring' -WorkspaceName 'law-prod' -Name 'dcr-app' -Location 'eastus' -Kind Windows

		Creates a Windows data collection rule and configures the specified workspace as a destination.
	#>
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

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string]
		$TableName,
		
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

		[string[]]
		$FilePatterns = @('C:\test.json'),

		[ServiceTransformAttribute()]
		[hashtable]
		$ServiceMap = @{}
	)
	begin {
		$services = $script:_serviceSelector.GetServiceMap($ServiceMap)
		Assert-EntraConnection -Cmdlet $PSCmdlet -Service $services.Azure
		$subCache = @{}

		# https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create
	}
	process {
		$subscriptionID = Resolve-Subscription -Name $Subscription -Services $services -Cache $subCache -Cmdlet $PSCmdlet

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
			$body.properties.agentSettings = $AgentSettings
		}
		if ($WorkspaceName) {
			$workspaceObject = Get-EalaWorkspace -Subscription $subscriptionID -ResourceGroup $ResourceGroup -Name $WorkspaceName -ServiceMap $services

			$body.properties.destinations.logAnalytics += @{
				workspaceResourceId = $workspaceObject.ID
				workspaceId         = $workspaceObject.Properties.customerId
				name                = $workspaceObject.Name
			}

			if ($TableName) {
				$tableObject = $workspaceObject | Get-EalaTable -Name $TableName

				# 32 characters is the limit
				$streamname = 'Custom-{0}' -f $tableObject.Name
				if ($streamname.Length -gt 32) { $streamname = $streamname.SubString(0, 32) }

				$body.properties.streamDeclarations = @{
					$streamname = @{
						columns = @(@($tableObject.Columns).ForEach{ @{ name = $_.name; type = $_.type } })
					}
				}
				$logFiles = $body.properties.dataSources['logFiles']
				if (-not $logFiles) { $logFiles = @() }
				$logFiles += @{
					streams      = @($streamname)
					filePatterns = $FilePatterns
					format       = 'json'
					name         = $streamname
				}
				$body.properties.dataSources['logFiles'] = $logFiles

				$dataFlowsTemp = $body.properties.dataFlows
				if (-not $dataFlowsTemp) { $dataFlowsTemp = @() }
				$dataFlowsTemp += @{
					streams      = @($streamname)
					destinations = @($workspaceObject.Name)
					transformKql = 'source'
					outputStream = $streamname
				}
				$body.properties.dataFlows = $dataFlowsTemp
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
			Invoke-EntraRequest @param -Body $body | ConvertTo-CollectionRule
		} -EnableException $true -PSCmdlet $PSCmdlet
	}
}