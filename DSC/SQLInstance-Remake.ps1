Configuration InstallSQLEngineRemake
{
  #---------------
  # Import Module 
  #---------------
  Import-DscResource -ModuleName InitSql
  Import-DscResource -ModuleName SqlServerDsc

  Node localhost
  {
    Init_Sql EssentialPackage 
    {
      WindowsFeatures = 'NET-Framework-45-Core'
      SrcPath         = '\\ntglabdevdata.file.core.windows.net\sqlsources\'
      SqlVer          = 'SQL2019'
    }

    SqlSetup DB 
    {
      DependsOn             = '[Dot_Net]Version45','[File_Source]SQL2019'
      InstanceName          = 'MSSQLSERVER'
      SourcePath            = 'C:\SQL2019'
      Features              = 'SQLENGINE'
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
      SAPwd                 = New-Object System.Management.Automation.PSCredential("sa", (ConvertTo-SecureString $Sqlpasswd -AsPlainText -Force))
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
      SourcePath            = 'C:\SQL2019'
    }

    SqlDatabase 'CreateDbaDatabase'
    {
      DependsOn             = '[SqlSetup]DB'
      InstanceName          = 'MSSQLSERVER'
      Name                  = 'DBA'
    }
  }
}