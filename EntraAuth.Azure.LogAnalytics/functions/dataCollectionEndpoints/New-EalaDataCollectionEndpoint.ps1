function New-EalaDataCollectionEndpoint {
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

		[Validate('Windows', 'Linux')]
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

		# https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create
	}
	process {
		$subscriptionID = Resolve-Subscription -Name $Subscription -Services $services -Cmdlet $PSCmdlet
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
			Service     = 'Azure'
			Method      = 'PUT'
			Path        = "subscriptions/$subscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionEndpoints/$Name"
			ContentType = 'application/json'
			Query       = @{
				'api-version' = '2024-03-11'
			} 
		}

		Invoke-PSFProtectedCommand -Action "Creating Data Collection Endpoint $Name in $subscriptionID > $ResourceGroup" -Target $Name -ScriptBlock {
			Invoke-EntraRequest @param -Body $body
		} -EnableException $true -PSCmdlet $PSCmdlet
	}
}