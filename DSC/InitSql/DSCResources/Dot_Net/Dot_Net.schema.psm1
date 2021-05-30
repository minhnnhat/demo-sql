Configuration Dot_Net {
  Param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [String[]] $WindowsFeatures
  )
  
  foreach ($WindowsFeature in $WindowsFeatures) {
    WindowsFeature NetFramework {
      Name   = $WindowsFeature
      Ensure = 'Present'
    }
  }
}