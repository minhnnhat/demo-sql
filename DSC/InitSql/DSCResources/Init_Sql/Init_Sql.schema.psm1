Configuration Init_Sql {
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String[]] $WindowsFeatures,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $SrcPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $SqlVer
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration' -ModuleVersion 9.1.0

    foreach ($WindowsFeature in $WindowsFeatures) {
        WindowsFeature NetFramework {
            Name   = $WindowsFeature
            Ensure = 'Present'
        }
    }

    xArchive GetSource 
    {
      Ensure = "Present"
      Path = "$SrcPath\$SqlVer.zip"
      Destination = "C:\"
      Credential = (Get-AutomationPSCredential 'cred_store')
    }
}