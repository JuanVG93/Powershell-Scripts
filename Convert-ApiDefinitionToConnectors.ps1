#Written by: Juan van Genderen
#Date: 12/01/2024
#Description: A script

function Search-JSONReference {
    <#
    
        This function will recursively search for '$ref' properties inside a PSCustomObject.
        All referenced schemas are then returned in an array
    
    #>
    param 
    (

        [Parameter(Mandatory = $true)] [PSCustomObject]$Object

    )

    $referencedSchemas = @()

    # Check if the object has a $ref property
    if ($Object.PSObject.Properties['$ref']) {

        $referencedSchemas += $($Object.'$ref')

    }

    # Recursively traverse the properties
    foreach ($property in $Object.PSObject.Properties) {

        $propertyValue = $property.Value

        # Check if the property value is another object
        if ($propertyValue -is [PSCustomObject]) {

            # Recursively search for references
            $referencedSchemas += Search-JSONReference -Object $propertyValue
        }

        # If the property value is an array, recursively search each element
        elseif ($propertyValue -is [System.Array]) {

            foreach ($arrayItem in $propertyValue) {

                if ($arrayItem -is [PSCustomObject]) {

                    $referencedSchemas += Search-JSONReference -Object $arrayItem

                }

            }

        }

    }

    return $referencedSchemas
}
    
Function Convert-APIDefinitionToDataConnectors {

    <#
    
        This function will read an OpenAPI definition file ($apiDefinitionPath) and convert the JSON to a PowerShell object.
        It iterates through each endpoint and HTTP Method defined in the OpenAPI file.
        For each endpoint, a folder structure is created based on tags.
        A new PowerShell object is created with the structure of a Data Connector for use in Azure.
        The output is saved to a new JSON file in the specified directory.
    
    #>

    Param 
    (

        [Parameter(Mandatory = $False)] [String]$apiDefinitionPath,
        [Parameter(Mandatory = $False)] [String]$dataConnectorPath

    )

    # Get the content from the source file and convert all characters to lowercase as otherwise we run into duplicate keys later on
    $sourceFile = (Get-Content -Raw -Path $apiDefinitionPath).ToLower() | ConvertFrom-Json

    # Initializing our output
    $output = @{}


    # Looping through each API Endpoint in the source file
    ForEach ($apiEndpoint in $sourceFile.paths.PSObject.Properties) {

        # Gathering the HTTP Methods for each endpoint
        $httpMethods = $apiEndpoint.Value.PSObject.Properties
        
        # Looping through each HTTP Method
        ForEach ($httpMethod in $httpMethods) {

            # Initializing the tags, parameters and responses
            $tags = if ($httpMethod.Value.tags) { $httpMethod.Value.tags -as [String] } else { "Uncategorized" }
            $parameters = if ($httpMethod.Value.parameters) { $httpMethod.Value.parameters } else { @() }
            $responses = if ($httpMethod.Value.responses) { $httpMethod.Value.responses } else { @{} }

            # Looping through each tag
            ForEach ($tag in $tags) {

                # Ensure that the necessary keys are initialized
                if (-not $output.ContainsKey($tag)) {

                    $output[$tag] = @{}

                }

                if (-not $output[$tag].ContainsKey($apiEndpoint.Name)) {

                    $output[$tag][$apiEndpoint.Name] = @{}

                }

                if (-not $output[$tag][$apiEndpoint.Name].ContainsKey($httpMethod.Name)) {

                    $output[$tag][$apiEndpoint.Name][$httpMethod.Name] = @{}

                }

                # Preparing the structure of the methodDetails object
                $methodDetails = @{

                    tags = $tags
                    summary = $httpMethod.Value.summary
                    operationId = $httpMethod.Value.operationId
                    parameters = @()
                    responses = @{}

                }

                # Saving the responses and parameters to their respective collections
                $methodDetails.responses = $responses
                $methodDetails.parameters = $parameters

                # Save the methodDetails to the tag key
                $output[$tag][$apiEndpoint.Name][$httpMethod.Name] = $methodDetails

            }

        }

    }

    # Inside the foreach ($tag in $output.Keys) loop
    foreach ($tag in $output.Keys | Sort-Object) {

        # Initialize the folder structure for storing the JSON files
        $tagFolder = Join-Path -Path $dataConnectorPath -ChildPath $tag

        # Only create a folder if it doesn't already exist
        if (-not (Test-Path $tagFolder)) {

            $null = New-Item -ItemType Directory -Path $tagFolder -Force

        }

        # Initializing the specContent to create a valid OpenAPI file with the correct structure
        $specContent = @{

            openapi = "3.0.0"

            info = @{

                title = "ConnectWise PSA - $($tag.ToUpper()) Data Connector"
                version = "1.0"

                contact = @{

                    name = "Juan van Genderen"
                    email = "juan.vangenderen@wavenetuk.com"

                }

            }

            paths = @{}

            components = @{

                schemas = @{}

            }

        }

        # Accumulate endpoints under $specContent.paths
        foreach ($apiEndpoint in $sourceFile.paths.PSObject.Properties) {

            # Loop through each HTTP Method
            foreach ($httpMethod in $apiEndpoint.Value.PSObject.Properties) {

                # Initializing the tags
                [Array]$tags = if ($httpMethod.Value.tags) { $httpMethod.Value.tags -as [String] } else { "Uncategorized" }

                # Check to make sure we have tags
                if ($tags -contains $tag) {

                    # Gather all schema references
                    $schemaReferences = Search-JSONReference -Object $httpMethod.Value

                    # Check to make sure we have schema references
                    if ($schemaReferences) {

                        # Loop through each schema reference
                        foreach ($schemaReference in $schemaReferences) {

                            # Extract the final part of the schema reference (E.G: #/components/schemas/NotificationRecipientReference becomes NotificationRecipientReference)
                            $schemaKeyword = Split-Path $schemaReference -Leaf

                            # Check to make sure this schema hasn't already been added to $specContent.components.schemas
                            if (-not $specContent.components.schemas[$schemaKeyword]) {

                                # Gather the schema from the source file
                                $schema = $sourceFile.components.schemas.PSObject.Properties | Where-Object { $_.Name -eq $schemaKeyword }

                                # Check if schema was found
                                if ($schema) {

                                    # Add schema to $specContent.components.schemas
                                    $specContent.components.schemas[$schemaKeyword] = $schema.Value

                                }

                            }

                        }

                    }
                    
                    # Convert $specContent.components.schemas to PSCustomObject
                    $currentSchemas = [PSCustomObject]$specContent.components.schemas

                    # Gather all schema references from the schemas that have been added already
                    $missingSchemaReferences = Search-JSONReference -Object $currentSchemas

                    # Check if any schema references still need to be added
                    if ($missingSchemaReferences) {
                        
                        # Loop through each missing schema reference
                        ForEach ($missingSchemaReference in $missingSchemaReferences) {
                        
                            # Extract the final part of the schema reference (E.G: #/components/schemas/NotificationRecipientReference becomes NotificationRecipientReference)
                            $missingKeyword = Split-Path $missingSchemaReference -Leaf

                            # Check to make sure this schema hasn't already been added to $specContent.components.schemas
                            if (-not $specContent.components.schemas[$missingKeyword]) {
                            
                                # Gather the schema from the source file
                                $missingSchema = $sourceFile.components.schemas.PSObject.Properties | Where-Object { $_.Name -eq $missingKeyword }

                                # Check if schema was found
                                if ($missingSchema) {
                                
                                    # Add schema to $specContent.components.schemas
                                    $specContent.components.schemas[$missingKeyword] = $missingSchema.Value

                                }
                            
                            }

                        }
                    
                    }

                    # Initialize the parameters, responses and requestbody
                    [Array]$parameters = if ($httpMethod.Value.parameters) { $httpMethod.Value.parameters } else { @() }
                    $responses = if ($httpMethod.Value.responses) { $httpMethod.Value.responses } else { @{} }
                    $requestbody = $httpMethod.Value.requestbody

                    # Initialize $specContent if it's not already initialized
                    if (-not $specContent.paths[$apiEndpoint.Name]) {

                        $specContent.paths[$apiEndpoint.Name] = @{}

                    }

                    # Preparing the structure of the specContent object ensuring we're appending to $specContent
                    $specContent.paths[$apiEndpoint.Name] += @{

                        $httpMethod.Name = @{

                            tags = $tags
                            summary = $httpMethod.Value.summary
                            operationId = $httpMethod.Value.operationId
                            parameters = $parameters
                            responses = $responses

                        }

                    }

                    # Include request body for the HTTP Methods that require one
                    if ($requestbody) {

                        $specContent.paths[$apiEndpoint.Name][$httpMethod.Name].requestBody = $requestbody

                    }

                }

            }

        }

        # Save the entire output to a single JSON file
        $specContent | ConvertTo-Json -Depth 100 | Out-File -FilePath (Join-Path -Path $tagFolder -ChildPath "$tag.json") -Force
        Write-Host "File written to $(Join-Path -Path $tagFolder -ChildPath "$tag.json")" -ForegroundColor Gray

    }

}
    
Function Main {

    Write-Host "[INFO] This script will convert an OpenAPI Definition into separate OpenAPI files which can be uploaded to Azure as Custom Data Connectors" -ForegroundColor Cyan

    Write-Host "[INFO] Running script..." -ForegroundColor Green
    Convert-APIDefinitionToDataConnectors -apiDefinitionPath "C:\Users\JuanVan-Genderen\Downloads\ConnectWise-PSA-API-OG.json" -dataConnectorPath "C:\Users\JuanVan-Genderen\Documents\Automation\Logic Apps\Data Connectors\ConnectWise PSA"
    Write-Host "[INFO] Done!" -ForegroundColor Green

}

Main
