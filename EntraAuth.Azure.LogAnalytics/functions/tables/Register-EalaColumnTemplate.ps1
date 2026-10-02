function Register-EalaColumnTemplate {
	<#
	.SYNOPSIS
		Registers a reusable table column template.

	.DESCRIPTION
		Registers a named column schema in the current module session for use by New-EalaTable.
		This allows a module that needs a Log Analytics table to prepare just how that should be set up, simplifying deployment for users of that module.

	.PARAMETER Name
		The unique name used to identify the column template.

	.PARAMETER Description
		A description of the template and its intended use.

	.PARAMETER Columns
		An array of hashtables defining the names and data types of the template columns.

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

		Documentation:
		https://learn.microsoft.com/en-us/rest/api/loganalytics/tables/create-or-update?view=rest-loganalytics-2026-03-01&tabs=HTTP#column

	.EXAMPLE
		PS C:\> Register-EalaColumnTemplate -Name 'AuditLog' -Description 'Standard audit event columns' -Columns @(@{ Name = 'EventId'; Type = 'int' }, @{ Name = 'Message'; Type = 'string' })

		Registers an AuditLog template containing integer EventId and string Message columns.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,
		
		[string]
		$Description,

		[Parameter(Mandatory = $true)]
		[PsfValidateScript('EntraAuth.Azure.LogAnalytics.TableColumnValidation')]
		[hashtable[]]
		$Columns
	)
	process {
		$script:_TableColumnTemplates[$Name] = [PSCustomObject]@{
			PSTypeName  = 'EntraAuth.Azure.LogAnalytics.ColumnTemplate'
			Name        = $Name
			Description = $Description
			Columns     = $Columns
		}
	}
}