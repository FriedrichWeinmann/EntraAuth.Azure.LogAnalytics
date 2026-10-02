function Resolve-Subscription {
	<#
	.SYNOPSIS
		Resolves a subscription name or ID to a subscription ID.

	.DESCRIPTION
		Returns a supplied subscription ID unchanged or resolves an exact subscription display name through Azure.
		Name resolution succeeds only when exactly one subscription matches and reports an error through the calling cmdlet for missing or ambiguous names.

	.PARAMETER Name
		The subscription display name or subscription ID to resolve.

	.PARAMETER Services
		A hashtable containing the service mappings used to query subscriptions.

	.PARAMETER Cache
		A hashtable caching subscriptions retrieved.
		Use to avoid repeated lookups within a command, but be sure to discard it when switching tenants.

	.PARAMETER Cmdlet
		The $PSCmdlet variable of the calling command, used to ensure errors happen within the scope of the caller, hiding this internal helper command from the user.

	.EXAMPLE
		PS C:\> Resolve-Subscription -Name 'Production' -Services $services -Cmdlet $PSCmdlet

		Resolves the subscription whose display name is Production using the supplied services and returns its subscription ID, reporting any resolution error through the calling cmdlet.
	#>
	[OutputType([string])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,

		[Parameter(Mandatory = $true)]
		[hashtable]
		$Services,

		[hashtable]
		$Cache = @{},

		[Parameter(Mandatory = $true)]
		$Cmdlet
	)
	process {
		# We don't validate GUIDs - we assume the user knew better
		# Presumably, bad input would still only lead to subsequent request failing
		if ($Name -as [guid]) { return $Name }

		if ($Cache.Count -lt 1) {
			foreach ($subscription in Get-EaaSubscription -ServiceMap $Services) {
				$Cache[$subscription.id] = $subscription
			}
		}

		$subscriptions = $Cache.Values | Where-Object DisplayName -EQ $Name
		if (@($subscriptions).Count -eq 1) {
			return $subscriptions.SubscriptionID
		}
		if (@($subscriptions).Count -gt 1) {
			Stop-PSFFunction -Message "Ambiguous Subscription! $Name resolved to $(@($subscriptions).Count) subscriptions ($($subscriptions.SubscriptionID -join ', '))" -Cmdlet $Cmdlet -EnableException $true
		}
		Stop-PSFFunction -Message "Invalid Subscription! $Name could not be resolved" -Cmdlet $Cmdlet -EnableException $true
	}
}