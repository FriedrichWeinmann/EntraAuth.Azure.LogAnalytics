Set-PSFScriptblock -Name 'EntraAuth.Azure.LogAnalytics.TableColumnValidation' -Scriptblock {
	$legalTypes = 'string', 'int', 'long', 'real', 'boolean', 'dateTime', 'guid', 'dynamic'
	$legalKeys = 'dataTypeHint', 'description', 'displayName', 'isDefaultDisplay', 'isHidden', 'name', 'type'
	foreach ($entry in $_) {
		if ($entry -isnot [hashtable]) { throw 'Invalid column entry: Not a hashtable!' }
		if (-not $entry.Name) { throw "Invalid column entry: Must contain a 'name' key" }
		if (-not $entry.type) { throw "Invalid column entry $($entry.name): Must contain a 'type' key" }
		if ($entry.type -notin $legalTypes) { throw "Invalid column entry $($entry.name): Illegal type $($entry.type) | Supported types: $($legalTypes -join ', ') | https://learn.microsoft.com/en-us/rest/api/loganalytics/tables/create-or-update?view=rest-loganalytics-2026-03-01&tabs=HTTP#columntypeenum" }

		foreach ($key in $entry.Keys) {
			if ($key -notin $legalKeys) { throw "Invalid column property: $key | Legal Entries: $($legalKeys -join ', ') | https://learn.microsoft.com/en-us/rest/api/loganalytics/tables/create-or-update?view=rest-loganalytics-2026-03-01&tabs=HTTP#column" }
		}
	}
	$true
} -Global