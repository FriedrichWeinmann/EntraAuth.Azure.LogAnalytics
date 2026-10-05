function New-EalaTable {
	<#
	.SYNOPSIS
		Creates a table in a Log Analytics workspace.

	.DESCRIPTION
		Creates a Log Analytics table from an explicit column schema or a registered column template.
		Custom table names receive the _CL suffix unless Literal is specified.

	.PARAMETER Subscription
		The name or ID of the target Azure subscription.

	.PARAMETER ResourceGroup
		The name of the resource group containing the workspace.

	.PARAMETER WorkspaceName
		The name of the Log Analytics workspace in which to create the table.

	.PARAMETER Name
		The table name. Unless Literal is specified, _CL is appended when it is not already present.

	.PARAMETER Plan
		The table plan. Options:
		
		- Basic: Can be queried, may have significant delays, lower cost
		- Analytics: All features, suitable for realtimne detection, but high cost
		- Auxiliary: Long Term Archive that is rarely read. Lowest cost.

		Defaults to: Basic

	.PARAMETER Categories
		The categories to associate with the table.
		Defaults to: @()

	.PARAMETER Columns
		An array of hashtables defining the table columns.
		Defaults to: @()

		Example:
		@{
			name = 'Message'
			type = 'string'
		}
		@{
			name = 'TimeGenerated'
			type = 'datetime'
		}
		@{
			name = 'Level'
			type = 'string'
		}
		@{
			name = 'Tags'
			type = 'dynamic'
		}

		Types: string, int, long, real, boolean, dateTime, guid, dynamic

		https://learn.microsoft.com/en-us/rest/api/loganalytics/tables/create-or-update?view=rest-loganalytics-2026-03-01&tabs=HTTP#column

	.PARAMETER ColumnTemplate
		The name of a registered column template.
		Column templates / presets can be defined using "Register-EalaColumnTemplate" and searched using "Get-EalaColumnTemplate".

	.PARAMETER Description
		A description of the table.

	.PARAMETER DisplayName
		The display name of the table.

	.PARAMETER Labels
		The labels to associate with the table.

	.PARAMETER Solutions
		The Azure solutions associated with the table.

	.PARAMETER RetentionInDays
		The interactive retention period, from 4 through 730 days. This parameter is supported only for the Analytics plan.

	.PARAMETER TotalRetentionInDays
		The total retention period, from 4 through 4383 days.

	.PARAMETER ProtectionLevel
		The table data protection level. Valid values are General and Protected.

	.PARAMETER Literal
		Uses Name exactly as supplied and disables automatic addition of the _CL suffix.

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
		PS C:\> New-EalaTable -Subscription 'Production' -ResourceGroup 'rg-monitoring' -WorkspaceName 'law-prod' -Name 'AppMetrics' -Plan Analytics -RetentionInDays 90 -ColumnTemplate 'StandardMetrics'

		Creates AppMetrics_CL from a registered column template with 90 days of interactive retention.
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

		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[PsfValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{2,61}[A-Za-z0-9]$', ErrorMessage = 'Invalid Name: {0}. Workspace names must be 4-63 characters long and only contain regular letters, numbers, and dashes.')]
		[string]
		$WorkspaceName,

		[Parameter(Mandatory = $true)]
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
		$Columns,
		
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
		$subCache = @{}

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
		$subscriptionID = Resolve-Subscription -Name $Subscription -Services $services -Cache $subCache -Cmdlet $PSCmdlet

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
		if ($Plan -eq 'Analytics') { $body.properties.retentionInDays = $RetentionInDays }
		if ($Categories) { $body.properties.schema.categories = @($Categories) }
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