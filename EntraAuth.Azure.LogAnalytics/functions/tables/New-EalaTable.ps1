function New-EalaTable {
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

		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[PsfValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{2,61}[A-Za-z0-9]$', ErrorMessage = 'Invalid Name: {0}. Workspace names must be 4-63 characters long and only contain regular letters, numbers, and dashes.')]
		[string]
		$WorkspaceName,

		[PsfValidatePattern('^[A-Za-z0-9-_]+$', ErrorMessage = 'Invalid Name: {0}. Table-names may only contain default letters of the 26-letter alphabet, numbers, dash and underscore')]
		[string]
		$Name,

		[ValidateSet('Basic', 'Analytics', 'Auxiliary')]
		[string]
		$Plan = 'Basic',

		[string[]]
		$Categories = @(),

		[Parameter(Mandatory = $true, ParameterSetName = 'Columns')]
		[PsfValidateScript('EntraAuth.Azure.LogAnalytics.TableColumnValidation')]
		[hashtable[]]
		$Columns = @(),
		
		[Parameter(Mandatory = $true, ParameterSetName = 'Template')]
		[PsfArgumentCompleter('EntraAuth.Azure.LogAnalytics.TableColumnTemplate')]
		[PsfValidateSet(TabCompletion = 'EntraAuth.Azure.LogAnalytics.TableColumnTemplate')]
		[string]
		$ColumnTemplate,

		[string]
		$Description,

		[string]
		$DisplayName,

		[string[]]
		$Labels,

		[string[]]
		$Solutions,

		[ValidateRange(4, 730)]
		[int]
		$RetentionInDays = -1,

		[ValidateRange(4, 4383)]
		[int]
		$TotalRetentionInDays = -1,

		[ValidateSet('General', 'Protected')]
		[string]
		$ProtectionLevel,

		[switch]
		$Literal,

		[ServiceTransformAttribute()]
		[hashtable]
		$ServiceMap = @{}
	)
	begin {
		$services = $script:_serviceSelector.GetServiceMap($ServiceMap)
		Assert-EntraConnection -Cmdlet $PSCmdlet -Service $services.Azure

		if ($PSBoundParameters.Keys -contains 'RetentionInDays' -and $Plan -ne 'Analytics') {
			Stop-PSFFunction -Message '"RetentionInDays" can be only specified in combination with an "Analytics" Plan' -EnableException $true -Cmdlet $PSCmdlet
		}

		if ($Columns) { $effectiveColumns = $Columns }
		else { $effectiveColumns = $script:_TableColumnTemplates[$ColumnTemplate].Columns }

		if (-not $effectiveColumns) {
			Stop-PSFFunction -Message 'No columns specified / resolved to!' -EnableException $true -Cmdlet $PSCmdlet
		}

		if (-not $Literal) {
			if ($Name -notmatch '_CL$') {
				$Name = "$($Name)_CL"
			}
		}
	}
	process {
		$subscriptionID = Resolve-Subscription -Name $Subscription -Services $services -Cmdlet $PSCmdlet

		$body = @{
			properties = @{
				plan                 = $Plan
				schema               = @{
					columns = @($effectiveColumns)
					name    = $Name
				}
				totalRetentionInDays = $TotalRetentionInDays
			}
		}
		if ($ProtectionLevel) { $body.properties.protectionLevel = $ProtectionLevel }
		if ($Plan -eq 'Discovery') { $body.properties.retentionInDays = $RetentionInDays }
		if ($Categories) { $body.properties.schema.categories = $@($Categories) }
		if ($Description) { $body.properties.schema.description = $Description }
		if ($DisplayName) { $body.properties.schema.displayName = $DisplayName }
		if ($Labels) { $body.properties.schema.labels = @($Labels) }
		if ($Solutions) { $body.properties.schema.solutions = @($Solutions) }

		Invoke-PSFProtectedCommand -Action "Creating table $Name in $subscriptionID > $ResourceGroup > $WorkspaceName" -Target $Name -ScriptBlock {
			Invoke-EntraRequest -Service $services.Azure -Method PUT -Path "subscriptions/$subscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/tables/$Name" -Query @{
				'api-version' = '2026-03-01'
			} -Body $body -ContentType 'application/json' | ConvertTo-Table
		} -EnableException $true -PSCmdlet $PSCmdlet
	}
}