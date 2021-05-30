Configuration xSQLInstance
{
  #---------------
  # Import Module 
  #---------------
  Import-DscResource -ModuleName InitSql
  Import-DscResource -ModuleName SqlServerDsc

  Node localhost
  {
    Init_Sql EssentialPackages
    {
      WindowsFeatures = 'NET-Framework-45-Core'
      SrcPath         = '\\ntglabdevdata.file.core.windows.net\sqlsources\'
      SqlVer          = 'SQL2019'
    }

    Setup_Sql SetupSqlInstance
    {
      DependsOn   = '[Init_Sql]EssentialPackages'
      SourcePath  = 'C:\SQL2019'
      Features    = 'SQLENGINE'
    }
  }
}