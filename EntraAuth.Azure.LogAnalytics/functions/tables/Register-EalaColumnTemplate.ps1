function Register-EalaColumnTemplate {
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