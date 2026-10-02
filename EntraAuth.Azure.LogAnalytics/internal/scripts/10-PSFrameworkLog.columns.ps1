$param = @{
	Name        = 'PSFrameworkLog'
	Description = 'Columns needed for PSFramework logging'
	Columns     = @(
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
		@{
			name = 'Data'
			type = 'dynamic'
		}
		@{
			name = 'ComputerName'
			type = 'string'
		}
		@{
			name = 'Runspace'
			type = 'string'
		}
		@{
			name = 'Username'
			type = 'string'
		}
		@{
			name = 'ModuleName'
			type = 'string'
		}
		@{
			name = 'FunctionName'
			type = 'string'
		}
		@{
			name = 'File'
			type = 'string'
		}
		@{
			name = 'Line'
			type = 'int'
		}
		@{
			name = 'Callstack'
			type = 'string'
		}
		@{
			name = 'TargetObject'
			type = 'dynamic'
		}
		@{
			name = 'ErrorRecord'
			type = 'dynamic'
		}
	)
}
Register-EalaColumnTemplate @param