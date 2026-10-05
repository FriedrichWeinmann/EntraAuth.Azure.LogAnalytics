function New-EalaDataCollectionEndpoint {
	<#
	.SYNOPSIS
		Creates an Azure Monitor data collection endpoint.

	.DESCRIPTION
		Creates a data collection endpoint with optional network access, platform, identity, tag, and SKU settings. If no location is specified, the resource group's location is used.

	.PARAMETER Subscription
		The name or ID of the target Azure subscription.

	.PARAMETER ResourceGroup
		The name of the resource group in which to create the endpoint.

	.PARAMETER Name
		The name of the data collection endpoint to create.

	.PARAMETER Location
		The Azure region in which to create the endpoint.
		Defaults to: Location of the Resource Group

	.PARAMETER Description
		A description of the data collection endpoint.

	.PARAMETER NetworkAccess
		The public network access mode. Valid values are Enabled, Disabled, and SecuredByPerimeter.
		Defaults to: Enabled

	.PARAMETER Tags
		A hashtable of tags to assign to the endpoint.

	.PARAMETER Kind
		The operating system kind associated with the endpoint. Valid values are Windows and Linux.

	.PARAMETER SystemIdentity
		Enables a system-assigned managed identity on the endpoint.

	.PARAMETER Sku
		A hashtable defining the endpoint SKU.

	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

	.PARAMETER ServiceMap
		Optional hashtable to map service names to specific EntraAuth service instances.
		Used for advanced scenarios where you want to use something other than the default Azure connection.
		Example: @{ Azure = 'MyAzure' }
		This will switch all Azure API calls to use the configuration defined in MyAzure.
		Defaults to: @{}

	.EXAMPLE
		PS C:\> New-EalaDataCollectionEndpoint -Subscription 'Production' -ResourceGroup 'rg-monitoring' -Name 'dce-prod' -Location 'eastus' -NetworkAccess SecuredByPerimeter -SystemIdentity

		Creates a data collection endpoint with perimeter-secured network access and a system-assigned identity.
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
		
		[Parameter(Mandatory = $true)]
		[string]
		$Name,
		
		[string]
		$Location,

		[string]
		$Description,

		[ValidateSet('Enabled', 'Disabled', 'SecuredByPerimeter')]
		[string]
		$NetworkAccess = 'Enabled',

		[hashtable]
		$Tags,

		[ValidateSet('Windows', 'Linux')]
		[string]
		$Kind,

		[switch]
		$SystemIdentity,

		[hashtable]
		$Sku,

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
			location   = $actualLocation
			properties = @{
				networkAcls = @{
					publicNetworkAccess = $NetworkAccess
				}
			}
		}
		if ($Description) { $body.properties.description = $Description }
		if ($Kind) {
			$body.kind = $Kind
		}
		if ($Tags) { $body.tags = $Tags }
		if ($Sku) { $body.sku = $Sku }
		if ($SystemIdentity) {
			$body.identity = @{
				tenantId = (Get-EntraToken -Service $services.Azure).TenantId
				type     = 'SystemAssigned'
			}
		}

		$param = @{
			Service     = $services.Azure
			Method      = 'PUT'
			Path        = "subscriptions/$subscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionEndpoints/$Name"
			ContentType = 'application/json'
			Query       = @{
				'api-version' = '2024-03-11'
			}
		}

		Invoke-PSFProtectedCommand -Action "Creating Data Collection Endpoint $Name in $subscriptionID > $ResourceGroup" -Target $Name -ScriptBlock {
			Invoke-EntraRequest @param -Body $body | ConvertTo-Endpoint
		} -EnableException $true -PSCmdlet $PSCmdlet
	}
}