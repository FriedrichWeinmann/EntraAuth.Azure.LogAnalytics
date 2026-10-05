function Write-EalaTableEntry {
	<#
	.SYNOPSIS
		Writes records to an Azure Monitor Logs table.

	.DESCRIPTION
		Sends one or more objects to an Azure Monitor Logs ingestion endpoint through a data collection rule.
		The target stream can be specified directly or inferred from the table name and the streams defined by the rule.
		Endpoint, rule, and authentication data can be cached when the command is called repeatedly.

	.PARAMETER Message
		One or more objects to submit as records. The objects are serialized as a JSON array in the ingestion request.

	.PARAMETER Subscription
		The name or ID of the Azure subscription containing the data collection endpoint and rule.

	.PARAMETER ResourceGroup
		The name of the resource group containing the data collection endpoint and rule.
		When omitted, the command searches the subscription for those resources.

	.PARAMETER DcrName
		The name of the data collection rule that defines the target stream.

	.PARAMETER DceName
		The name of the data collection endpoint used to ingest the records.

	.PARAMETER Table
		The table name used to select a matching stream from the data collection rule when Stream is not specified.
		If the rule contains only one stream, that stream is selected automatically.
		Defaults to: <default>

	.PARAMETER Stream
		The exact data collection rule stream to which the records are written.
		Use this parameter when the stream cannot be inferred unambiguously from the table name.

	.PARAMETER Cache
		A reusable hashtable in which authentication tokens, endpoints, rules, and resolved streams are cached.
		Use the same hashtable across calls to avoid retrieving these values repeatedly.
		Defaults to: @{}

	.PARAMETER EntraToken
		An existing EntraAuth access token for https://monitor.azure.com/.
		When omitted, the command obtains a compatible token from the current Azure connection.

	.PARAMETER ServiceMap
		Optional hashtable to map service names to specific EntraAuth service instances.
		Used for advanced scenarios where you want to use something other than the default Azure connection.
		Example: @{ Azure = 'MyAzure' }
		This will switch all Azure API calls to use the configuration defined in MyAzure.
		Defaults to: @{}

	.EXAMPLE
		PS C:\> Write-EalaTableEntry -Message $records -Subscription 'Production' -ResourceGroup 'rg-monitoring' -DcrName 'dcr-app' -DceName 'dce-app' -Table 'AppLogs_CL'

		Writes the objects in $records to the stream matching the AppLogs_CL table.

	.EXAMPLE
		PS C:\> Write-EalaTableEntry -Message $record -Subscription 'Production' -ResourceGroup 'rg-monitoring' -DcrName 'dcr-app' -DceName 'dce-app' -Stream 'Custom-AppLogs' -Cache $cache

		Writes a record to an explicitly selected stream and reuses the supplied cache for repeated calls.
	#>
	[CmdletBinding(DefaultParameterSetName = 'ByTable')]
	param (
		[Parameter(Mandatory = $true)]
		[object[]]
		$Message,

		[Parameter(Mandatory = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.Subscription')]
		[string]
		$Subscription,

		[PsfArgumentCompleter('EntraAuth.Azure.ResourceGroup')]
		[string]
		$ResourceGroup,

		[Parameter(Mandatory = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.LogAnalytics.DataCollectionRule')]
		[string]
		$DcrName,
		
		[Parameter(Mandatory = $true)]
		[PsfArgumentCompleter('EntraAuth.Azure.LogAnalytics.DataCollectionEndpoint')]
		[string]
		$DceName,
		
		[Parameter(ParameterSetName = 'ByTable')]
		[string]
		$Table = '<default>',
		
		[Parameter(Mandatory = $true, ParameterSetName = 'ByStream')]
		[string]
		$Stream,

		[hashtable]
		$Cache = @{},

		$EntraToken,

		[ServiceTransformAttribute()]
		[hashtable]
		$ServiceMap = @{}
	)

	begin {
		if (-not $cache.$Subscription) {
			$cache[$Subscription] = @{
				Endpoint = @{}
				Rule     = @{}
			}
		}
		
		#region Resolve Token
		$services = $script:_serviceSelector.GetServiceMap($ServiceMap)
		if ($EntraToken) { $tokenToUse = $EntraToken }
		elseif ($Cache.$Subscription.Token) { $tokenToUse = $Cache.$Subscription.Token }
		else {
			Assert-EntraConnection -Cmdlet $PSCmdlet -Service $services.Azure
			$azToken = Get-EntraToken -Service $services.Azure
			$commonParam = @{
				ClientID          = $azToken.ClientID
				TenantID          = $azToken.TenantID
				Resource          = 'https://monitor.azure.com/'
				AuthenticationUrl = $azToken.AuthenticationUrl
			}

			if ($azToken.RefreshToken) {
				$tokenToUse = Connect-EntraService @commonParam -Scopes '.default' -UseRefreshToken
				$Cache.$Subscription.Token = $tokenToUse
			}
			elseif ($azToken.Certificate) {
				$tokenToUse = Connect-EntraService @commonParam -Certificate $azToken.Certificate
				$Cache.$Subscription.Token = $tokenToUse
			}
			elseif ($azToken.ClientSecret) {
				$tokenToUse = Connect-EntraService @commonParam -ClientSecret $azToken.ClientSecret
				$Cache.$Subscription.Token = $tokenToUse
			}
			elseif ($azToken.Type -eq 'Identity') {
				$param = @{}
				if ($azToken.IdentityID) { $param.IdentityID = $azToken.IdentityID }
				if ($azToken.IdentityType) { $param.IdentityType = $azToken.IdentityType }
				$tokenToUse = Connect-EntraService @param -Identity -Resource 'https://monitor.azure.com/' -AuthenticationUrl $azToken.AuthenticationUrl
				$Cache.$Subscription.Token = $tokenToUse
			}
			elseif ($azToken.Type -eq 'Federated') {
				$tokenToUse = Connect-EntraService @commonParam -Federated -FederationProvider $azToken.FederationProvider.Name
				$Cache.$Subscription.Token = $tokenToUse
			}
			elseif ($azToken.Type -eq 'AzAccount') {
				$tokenToUse = Connect-EntraService -AsAzAccount -ShowDialog $azTOken.ShowDialog -Resource 'https://monitor.azure.com/' -AuthenticationUrl $azToken.AuthenticationUrl
				$Cache.$Subscription.Token = $tokenToUse
			}
		}
		#endregion Resolve Token
	}
	process {
		$commonParam = @{
			Subscription = $Subscription
			ServiceMap   = $ServiceMap
		}
		if ($ResourceGroup) { $commonParam.ResourceGroup = $ResourceGroup }

		if (-not $Cache.$Subscription.Endpoint[$DceName]) {
			$Cache.$Subscription.Endpoint[$DceName] = Get-EalaDataCollectionEndpoint @commonParam -Name $DceName
			if (-not $Cache.$Subscription.Endpoint[$DceName]) { Stop-PSFFunction -String 'Write-EalaTableEntry.Error.EndpointNotFound' -StringValues $DceName -EnableException $true -Category ObjectNotFound -Cmdlet $PSCmdlet }
		}
		if (-not $Cache.$Subscription.Rule[$DcrName]) {
			$Cache.$Subscription.Rule[$DcrName] = Get-EalaDataCollectionRule @commonParam -Name $DcrName | Add-Member -MemberType NoteProperty -Name _Streams -Value @{} -PassThru -Force
			if (-not $Cache.$Subscription.Rule[$DcrName]) { Stop-PSFFunction -String 'Write-EalaTableEntry.Error.RuleNotFound' -StringValues $DcrName -EnableException $true -Category ObjectNotFound -Cmdlet $PSCmdlet }
		}
		
		#region Calculate Stream
		if ($Stream) { $streamName = $Stream }
		else {
			$streams = $Cache.$Subscription.Rule[$DcrName].properties.dataFlows.streams
			if ($Cache.$Subscription.Rule[$DcrName]._Streams.$Table) {
				$streamName = $Cache.$Subscription.Rule[$DcrName]._Streams.$Table
			}
			elseif (@($streams).Count -eq 1) {
				$streamName = $($streams)
				$Cache.$Subscription.Rule[$DcrName]._Streams[$Table] = $streamName
			}
			elseif (@($streams | Where-Object { $_ -match $Table }).Count -eq 1) {
				$streamName = $streams | Where-Object { $_ -match $Table }
				$Cache.$Subscription.Rule[$DcrName]._Streams[$Table] = $streamName
			}
			elseif (-not $streams) {
				Stop-PSFFunction -String 'Write-EalaTableEntry.Error.NoStreams' -StringValues $DcrName -EnableException $true -Category InvalidData -Cmdlet $PSCmdlet
			}
			else {
				Stop-PSFFunction -String 'Write-EalaTableEntry.Error.AmbiguousStreams' -StringValues ($streams -join ', '), $Table -EnableException $true -Category InvalidData -Cmdlet $PSCmdlet
			}
		}
		#endregion Calculate Stream
	
		Invoke-EntraRequest -Method Post -Path "$($Cache.$Subscription.Endpoint[$DceName].LinkIngestion)/dataCollectionRules/$($Cache.$Subscription.Rule[$DcrName].ImmutableId)/streams/$streamName" -Query @{
			'api-version' = '2023-01-01'
		} -ContentType 'application/json' -Body @($Message) -Token $tokenToUse
	}
}