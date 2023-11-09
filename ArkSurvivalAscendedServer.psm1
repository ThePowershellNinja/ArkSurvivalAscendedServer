
# Get all the public and private function definitions
$publicFunctions = @(Get-ChildItem -Path $PSScriptRoot\PublicFunctions\*.ps1)
$privateFunctions = @(Get-ChildItem -Path $PSScriptRoot\PrivateFunctions\*.ps1)
Write-verbose Hello
# Get Class definitions
$classes = @(Get-ChildItem -Path $PSScriptRoot\Classes\*.ps1)

# Import all the definitions
foreach ($definition in @($publicFunctions + $privateFunctions + $classes)) {

    try {
        Write-Verbose ('Importing {0}' -f $definition.FullName)
        . $definition.FullName
    } catch {
        throw ('Failed to import {0}: {1}' -f $definition.FullName, $_)
    }
}

# Export everything and let the Module Manifest sort out the rest
Export-ModuleMember -Function *