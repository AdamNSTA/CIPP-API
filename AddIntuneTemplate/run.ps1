using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Log-Request -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Accessed this API" -Sev "Debug"

$GUID = (New-Guid).GUID
try { 
    if ($Request.body.rawJSON) {       
        if (!$Request.body.displayname) { throw "You must enter a displayname" }
        if ($null -eq ($Request.body.Rawjson | ConvertFrom-Json)) { throw "the JSON is invalid" }
        

        $object = [PSCustomObject]@{
            Displayname = $request.body.displayname
            Description = $request.body.description
            RAWJson     = $request.body.RawJSON
            Type        = $request.body.TemplateType
            GUID        = $GUID
        } | ConvertTo-Json
        New-Item Config -ItemType Directory -ErrorAction SilentlyContinue
        Set-Content "Config\$($GUID).IntuneTemplate.json" -Value $Object -Force
        Log-Request -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Created intune policy template named $($Request.body.displayname) with GUID $GUID" -Sev "Debug"

        $body = [pscustomobject]@{"Results" = "Successfully added template" }
    }
    else {
        $TenantFilter = $request.query.TenantFilter
        $URLName = $Request.query.URLName
        $ID = $request.query.id
        switch ($URLName) {

            "configurationPolicies" {
                $Type = "Catalog"
                $Template = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/deviceManagement/$($urlname)('$($ID)')?`$expand=settings" -tenantid $tenantfilter | Select-Object name, description, settings, platforms, technologies
                $TemplateJson = $Template | ConvertTo-Json -Depth 10
                $DisplayName = $template.name


            } 
            "deviceConfigurations" {
                $Type = "Device"
                $Template = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/deviceManagement/$($urlname)/$($ID)" -tenantid $tenantfilter | Select-Object displayname, description, omaSettings, '@odata.type'
                $DisplayName = $template.displayName
                $TemplateJson = ConvertTo-Json -InputObject $Template -Depth 10 -Compress
            }
            "groupPolicyConfigurations" {
                $Type = "Admin"
                $Template = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/deviceManagement/$($urlname)('$($ID)')" -tenantid $tenantfilter
                $DisplayName = $Template.displayName
                $TemplateJsonSource = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/deviceManagement/$($urlname)('$($ID)')/definitionValues?`$expand=definition(`$select=id)" -tenantid $tenantfilter | Select-Object enabled, @{label = 'definition@odata.bind'; expression = { "https://graph.microsoft.com/beta/deviceManagement/groupPolicyDefinitions('$($_.definition.id)')" } }
                $input = [pscustomobject]@{
                    added      = @($TemplateJsonSource)
                    updated    = @()
                    deletedIds = @()

                }
                $TemplateJson = ConvertTo-Json -InputObject $input -Depth 5 -Compress
            }
        }
       

        $object = [PSCustomObject]@{
            Displayname = $DisplayName
            Description = $Template.Description
            RAWJson     = $TemplateJson
            Type        = $Type
            GUID        = $GUID
        } | ConvertTo-Json
        New-Item Config -ItemType Directory -ErrorAction SilentlyContinue
        Set-Content "Config\$($GUID).IntuneTemplate.json" -Value $Object -Force
        Log-Request -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Created intune policy template $($Request.body.displayname) with GUID $GUID using an original policy from a tenant" -Sev "Debug"

        $body = [pscustomobject]@{"Results" = "Successfully added template" }
    }
}
catch {
    Log-Request -user $request.headers.'x-ms-client-principal'  -API $APINAME -message "Intune Template Deployment failed: $($_.Exception.Message)" -Sev "Error"
    $body = [pscustomobject]@{"Results" = "Intune Template Deployment failed: $($_.Exception.Message)" }
}


# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $body
    })
