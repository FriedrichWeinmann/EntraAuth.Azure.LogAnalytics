function Get-EalaColumnTemplate {
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