function Write-EalaTableEntry {
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
		#region Resolve Token
		$services = $script:_serviceSelector.GetServiceMap($ServiceMap)
		if ($EntraToken) { $tokenToUse = $EntraToken }
		elseif ($cache.Token) { $tokenToUse = $cache.Token }
		else {
			Assert-EntraConnection -Cmdlet $PSCmdlet -Service $services.Azure
			$azToken = Get-EntraToken -Service Azure
			$commonParam = @{
				ClientID          = $azToken.ClientID
				TenantID          = $azToken.TenantID
				Resource          = 'https://monitor.azure.com/'
				AuthenticationUrl = $azToken.AuthenticationUrl
			}

			if ($azToken.RefreshToken) {
				$tokenToUse = Connect-EntraService @commonParam -Scopes '.default' -UseRefreshToken
				$Cache.Token = $tokenToUse
			}
			elseif ($azToken.Certificate) {
				$tokenToUse = Connect-EntraService @commonParam -Certificate $azToken.Certificate
				$Cache.Token = $tokenToUse
			}
			elseif ($azToken.ClientSecret) {
				$tokenToUse = Connect-EntraService @commonParam -ClientSecret $azToken.ClientSecret
				$Cache.Token = $tokenToUse
			}
			elseif ($azToken.Type -eq 'Identity') {
				$param = @{}
				if ($azToken.IdentityID) { $param.IdentityID = $azToken.IdentityID }
				if ($azToken.IdentityType) { $param.IdentityType = $azToken.IdentityType }
				$tokenToUse = Connect-EntraService @param -Identity -Resource 'https://monitor.azure.com/' -AuthenticationUrl $azToken.AuthenticationUrl
				$Cache.Token = $tokenToUse
			}
			elseif ($azToken.Type -eq 'Federated') {
				$tokenToUse = Connect-EntraService @commonParam -Federated -FederationProvider $azToken.FederationProvider.Name
				$Cache.Token = $tokenToUse
			}
			elseif ($azToken.Type -eq 'AzAccount') {
				$tokenToUse = Connect-EntraService -AsAzAccount -ShowDialog $azTOken.ShowDialog -Resource 'https://monitor.azure.com/' -AuthenticationUrl $azToken.AuthenticationUrl
				$Cache.Token = $tokenToUse
			}
		}
		#endregion Resolve Token
	}
	process {
		if (-not $Cache.Endpoint) { $Cache.Endpoint = @{} }
		if (-not $Cache.Rule) { $Cache.Rule = @{} }

		$commonParam = @{
			Subscription = $Subscription
			ServiceMap   = $ServiceMap
		}
		if ($ResourceGroup) { $commonParam.ResourceGroup = $ResourceGroup }

		if (-not $Cache.Endpoint[$DceName]) {
			$Cache.Endpoint[$DceName] = Get-EalaDataCollectionEndpoint @commonParam -Name $DceName
			if (-not $Cache.Endpoint[$DceName]) { Stop-PSFFunction -String 'Write-EalaTableEntry.Error.EndpointNotFound' -StringValues $DceName -EnableException $true -Category ObjectNotFound -Cmdlet $PSCmdlet }
		}
		if (-not $Cache.Rule[$DcrName]) {
			$Cache.Rule[$DcrName] = Get-EalaDataCollectionRule @commonParam -Name $DcrName | Add-Member -MemberType NoteProperty -Name _Streams -Value @{} -PassThru -Force
			if (-not $Cache.Rule[$DcrName]) { Stop-PSFFunction -String 'Write-EalaTableEntry.Error.RuleNotFound' -StringValues $DcrName -EnableException $true -Category ObjectNotFound -Cmdlet $PSCmdlet }
		}
		
		#region Calculate Stream
		if ($Stream) { $streamName = $Stream }
		else {
			$streams = $Cache.Rule[$DcrName].properties.dataFlows.streams
			if ($Cache.Rule[$DcrName]._Streams.$Table) {
				$streamName = $Cache.Rule[$DcrName]._Streams.$Table
			}
			elseif (@($streams).Count -eq 1) {
				$streamName = $($streams)
				$Cache.Rule[$DcrName]._Streams[$Table] = $streamName
			}
			elseif (@($streams | Where-Object { $_ -match $Table }).Count -eq 1) {
				$streamName = $streams | Where-Object { $_ -match $Table }
				$Cache.Rule[$DcrName]._Streams[$Table] = $streamName
			}
			elseif (-not $streams) {
				Stop-PSFFunction -String 'Write-EalaTableEntry.Error.NoStreams' -StringValues $DcrName -EnableException $true -Category InvalidData -Cmdlet $PSCmdlet
			}
			else {
				Stop-PSFFunction -String 'Write-EalaTableEntry.Error.AmbiguousStreams' -StringValues ($streams -join ', '), $Table -EnableException $true -Category InvalidData -Cmdlet $PSCmdlet
			}
		}
		#endregion Calculate Stream
	
		Invoke-EntraRequest -Method Post -Path "$($Cache.Endpoint[$DceName].LinkIngestion)/dataCollectionRules/$($Cache.Rule[$DcrName].ImmutableId)/streams/$streamName" -Query @{
			'api-version' = '2023-01-01'
		} -ContentType 'application/json' -Body @($Message) -Token $tokenToUse
	}
}