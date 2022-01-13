try {
    Import-UnixCompleters
}
catch [System.Management.Automation.CommandNotFoundException]
{
    # nothing to do
}
