Import-Module -DisableNameChecking -Name ([System.IO.Path]::Combine($PSScriptRoot,'Modules','PowerProfile'))

# Explicitly end any processing here
exit 0

### HINT: There might be scripts or anything similar that will simply add lines
###       at the end of your profile.ps1 file.
###       If that was the case, the lines below shall be moved into dedicated
###       script files as part of any of the profile directories (depending on
###       your environment). Until you do this, the code will be ignored to
###       ensure you have checked how it fits into your PS profile concept.


