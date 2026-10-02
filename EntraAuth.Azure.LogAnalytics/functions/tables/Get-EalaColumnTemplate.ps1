function Get-EalaColumnTemplate {
	<#
	.SYNOPSIS
		Retrieves registered table column templates.

	.DESCRIPTION
		Returns column templates registered in the current module session. Template names can be filtered with a wildcard pattern.

	.PARAMETER Name
		The template name or wildcard pattern to retrieve.
		Defaults to: *

	.EXAMPLE
		PS C:\> Get-EalaColumnTemplate -Name 'Audit*'

		Returns all registered column templates whose names begin with Audit.
	#>
	[CmdletBinding()]
	param (
		[PsfArgumentCompleter('EntraAuth.Azure.LogAnalytics.TableColumnTemplate')]
		[string]
		$Name = '*'
	)
	process {
		$script:_TableColumnTemplates.Values | Where-Object Name -Like $Name
	}
}