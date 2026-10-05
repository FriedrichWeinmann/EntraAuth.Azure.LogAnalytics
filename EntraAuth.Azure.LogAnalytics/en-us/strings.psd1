@{
	'Write-EalaTableEntry.Error.AmbiguousStreams' = 'Ambiguous Streams Resolved for table "{1}": {0}. Provide either with the parameter "-Stream" instead of Table to resolve this ambiguity.' # ($streams -join ', '), $Table
	'Write-EalaTableEntry.Error.EndpointNotFound' = 'Unable to find/resolve Data Collection Endpoint "{0}"' # $DceName
	'Write-EalaTableEntry.Error.NoStreams'        = 'The Data Collection Rule "{0}" does not define any streams in their DataFlows' # $DcrName
	'Write-EalaTableEntry.Error.RuleNotFound'     = 'Unable to find/resolve Data Collection Rule "{0}"' # $DcrName
}