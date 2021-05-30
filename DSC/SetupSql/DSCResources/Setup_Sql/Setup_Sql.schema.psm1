Configuration Setup_Sql {
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $SourcePath,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $Features
    )

    Import-DscResource -ModuleName SqlServerDsc

    SqlSetup DB 
    {
        InstanceName          = 'MSSQLSERVER'
        SourcePath            = $SourcePath
        Features              = $Features
        InstallSharedDir      = 'C:\Program Files\Microsoft SQL Server'
        InstallSharedWOWDir   = 'C:\Program Files (x86)\Microsoft SQL Server'
        InstanceDir           = 'C:\Program Files\Microsoft SQL Server'
        SQLSysAdminAccounts   = @('Administrators')
        InstallSQLDataDir     = 'C:\Program Files\Microsoft SQL Server\MSSQL19.MSSQLSERVER\MSSQL\Data'
        SQLUserDBDir          = 'C:\Program Files\Microsoft SQL Server\MSSQL19.MSSQLSERVER\MSSQL\Data'
        SQLUserDBLogDir       = 'C:\Program Files\Microsoft SQL Server\MSSQL19.MSSQLSERVER\MSSQL\Data'
        SQLTempDBDir          = 'C:\Program Files\Microsoft SQL Server\MSSQL19.MSSQLSERVER\MSSQL\Data'
        SQLTempDBLogDir       = 'C:\Program Files\Microsoft SQL Server\MSSQL19.MSSQLSERVER\MSSQL\Data'
        SQLBackupDir          = 'C:\Program Files\Microsoft SQL Server\MSSQL19.MSSQLSERVER\MSSQL\Data'
        SecurityMode          = 'SQL'
        SAPwd                 = (Get-AutomationPSCredential 'cred_sql')
        UpdateEnabled         = $true
        SQLSvcStartupType     = 'Automatic'
    }

    SqlProtocol 'ChangeTcpIpOnDefaultInstance'
    {
        InstanceName           = 'MSSQLSERVER'
        ProtocolName           = 'TcpIp'
        Enabled                = $true
        ListenOnAllIpAddresses = $true
        KeepAlive              = 20000
    }

    SqlConfiguration 'AllowRemoteAccess'
    {
        DependsOn      = '[SqlSetup]DB'
        InstanceName   = 'MSSQLSERVER'
        OptionName     = 'remote access'
        OptionValue    = 1
        RestartService = $true
    }

    SqlWindowsFirewall 'AllowFirewall'
    {
        DependsOn             = '[SqlSetup]DB'
        InstanceName          = 'MSSQLSERVER'
        Features              = 'SQLEngine'
        SourcePath            = $SourcePath
    }

    SqlDatabase 'CreateDbaDatabase'
    {
        DependsOn             = '[SqlSetup]DB'
        InstanceName          = 'MSSQLSERVER'
        Name                  = 'DBA'
    }
}