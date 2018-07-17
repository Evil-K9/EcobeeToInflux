##########################################
# User Variables
##########################################
# Go here to register as a developer and get your own API key - 
# https://www.ecobee.com/home/developer/api/introduction/index.shtml
# This script will take care of generating your PIN, and getting the access and refresh tokens!

$apiKey = "" ### FILL THIS IN!
$TokenFile = "$Script:PSScriptRoot\Ecobee.xml" # File to save the tokens

# Influx Variables

$InfluxHost = "http://<yourServer>:8086"  # http(s)://hostname:port
# Uncomment the line near the bottom "Invoke-RestMethod ..." and run it one time to create the database for you.
$InfluxDBName = "hvac"
$influxTable = "ecobee"
$InfluxAuthentication = $true
$InfluxUser = "hvac"
$InfluxPass = "passwordHVAC"
$GlobalTags = "Location=Home"

##########################################

# Encode the user/pass
$Credentials = "$($InfluxUser):$($InfluxPass)"
$AuthString = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Credentials))


#region Ecobee API commands

# Obtain Pin and Auth code
<# JavaScript example
var apiKey = $('#apiKey').val();    
var url = "https://api.ecobee.com/authorize?response_type=ecobeePin&client_id=".concat(apiKey).concat("&scope=smartWrite");    
$.getJSON(url,  function(data) {
    var response = JSON.stringify(data, null, 4);
     $('#authorizeResponse').html(response);
});
#>

# The PIN is only needed to authenticate this app's API Key to a user's account.
function Get-EcobeePIN {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$apikey
    )

    if (!$apiKey) { Write-Error "No API Key found!"; exit; }
    $url = "https://api.ecobee.com/authorize?response_type=ecobeePin&client_id="+ $apiKey + "&scope=smartWrite"

    $Result = Invoke-RestMethod -Method GET -Uri $url
    
    # User takes the PIN from this and adds it to "My Apps"
    $Result
}

# Obtain Access Token
<# Java Script
apiKey = $('#apiKey').val();
authCode = $('#authCode').val();
var url = "https://api.ecobee.com/token"
var data = "grant_type=ecobeePin&code=".concat(authCode).concat("&client_id=").concat(apiKey);
$.post(url, data, function(resp) {
    var response = JSON.stringify(resp, null, 4);
    $('#tokenResponse').html(response);
}, 'json');
#>

# Use this function just after the user adds thie app
function Get-EcobeeFirstToken {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$authCode,
        [Parameter(Mandatory=$true)]
        [string]$apikey
    )

    $url = "https://api.ecobee.com/token"
    $data = "grant_type=ecobeePin&code=" + $authCode + "&client_id=" + $apiKey

    $Result = Invoke-RestMethod -Method POST -Uri $url -Body $data

    $Result
}

# Renew token
<# JavaScript
apiKey = $('#apiKey').val();
refreshToken = $('#refreshToken').val();
   
var url = "https://api.ecobee.com/token";
var data = "grant_type=refresh_token&code=".concat(refreshToken).concat("&client_id=").concat(apiKey);
      
$.post(url, data, function(resp) {
    var response = JSON.stringify(resp, null, 4);
      $('#refreshTokenResponse').html(response);
}, 'json');  
#>

function Get-EcobeeNewToken {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$RefreshToken,
        [Parameter(Mandatory=$true)]
        [String]$apiKey
    )

    $url = "https://api.ecobee.com/token"
    $data = "grant_type=refresh_token&code=" + $RefreshToken + "&client_id=" + $apiKey
    
    
    $Result = Invoke-RestMethod -Method POST -Uri $url -Body $data
    
    $Result
}

function Save-EcobeeTokens {
    Param(
        [psobject]$Tokens
    )

    # Validate $Tokens
    if (!($Tokens.refresh_token)) { write-error "No refresh token found! Not saving!"; exit; }

    # Add useful properties
    Add-Member -InputObject $Tokens -MemberType NoteProperty -Name expires_at -Value (Get-Date).AddSeconds($Tokens.expires_in) -Force
    Add-Member -InputObject $Tokens -MemberType NoteProperty -Name last_refresh -Value (Get-Date) -Force

    $Tokens | Export-Clixml -Path $TokenFile
}

<# Get Temperature

# cURL example
curl -s -H 'Content-Type: text/json' -H 'Authorization: Bearer ACCESS_TOKEN' 'https://api.ecobee.com/1/thermostat?format=json&body=\{"selection":\{"selectionType":"registered","selectionMatch":"","includeRuntime":true\}\}'
#>

function Get-EcobeeDetails {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$AccessToken
    )
    if (!$AccessToken) { Write-Error "No Access Token!"; exit; }

    $url = 'https://api.ecobee.com/1/thermostat?format=json&body={"selection":{"selectionType":"registered","selectionMatch":"","includeRuntime":true,"includeSensors":true,"includeSettings":true,"includeAlerts":true,"includeEvents":true,"includeEquipmentStatus":true,"includeWeather":true}}'
    $header = "Bearer $accessToken"

    $Result = Invoke-RestMethod -Method GET -Uri $url -Headers @{Authorization=$header} -ContentType "application/json"

    $Result
}

<# Get a runtime report
# cURL example
curl -s --request GET -H "Content-Type: application/json;charset=UTF-8" -H "Authorization: Bearer jOskdWuwPC3Aag2oifRPZHNFGboLBFz2" 'https://api.ecobee.com/1/runtimeReport?format=json&body=\{"startDate":"2015-01-01","endDate":"2015-01-03","columns":"auxHeat1,compCool1,fan,outdoorTemp,zoneAveTemp","selection":\{"selectionType":"thermostats","selectionMatch":"318324702718"\}\}'

For exmple, the row:

"2014-12-31,19:55:00,30,0,30,17.6,69.4,"                            
                            
Represents the time slot at 7:55pm on December 31, 2014 thermostat time. The heating and fan was on for 30 seconds within this 5 minutes time slot. 
The outside temperature was 17.6℉ and the average indoor temperature was 69.4℉.
#>


function Get-EcobeeSummary {
    if (!$accessToken) { Write-Error "No Access Token!"; exit; }

    $url = 'https://api.ecobee.com/1/thermostatSummary?format=json&body={"selection":{"selectionType":"registered","selectionMatch":"","includeRuntime":true,"includeSensors":true,"includeSettings":true,"includeAlerts":true,"includeEvents":true,"includeEquipmentStatus":true,"includeWeather":true,"includeElectricity":true}}'
    $header = "Bearer $accessToken"

    $Result = Invoke-RestMethod -Method GET -Uri $url -Headers @{Authorization=$header} -ContentType "application/json"

    $Result
}

#endregion Ecobee API commands

#region Ecobee App Registration and Data Retrieval

<# Workflow for first time authentication
 Request PIN using apikey ->
 <- Pin returned
 Send user to add pin to their dashboard ->
 Obtain access token with that pin ->
 <- access & Refresh tokens
#>

if (!(Test-path $TokenFile) -or !($Tokens = Import-Clixml -Path $TokenFile).refresh_token) { # Assume app is not registered, begin registration routine

    Write-Host "No token file was found at the path specified, or it contains no refresh token. The following proceedure will walk you through registering this script as an App with your Ecobee account.`n" -ForegroundColor Yellow
    Pause
    
    $PIN = Get-EcobeePIN -apikey $apiKey
    ""
    "Here is your PIN: $($PIN.ecobeePin)"
    ""
    "Goto ecobee.com, login to the web portal and click on the 'My Apps' tab. This will bring you to a page where you can add an application by authorizing your ecobeePin."
    "To do this, paste your ecobeePin and click 'Validate'. The next screen will display any permissions the app requires and will ask you to click 'Authorize' to add the application."
    Write-Host "Once you've done this, " -NoNewline; Pause

    Write-Verbose "Fetching first tokens..."
    $Tokens = Get-EcobeeFirstToken -apikey $apikey -authCode $PIN.code
    Save-EcobeeTokens -object $Tokens

    Write-Verbose "Fetching refresh tokens..."
    $Tokens = Get-EcoBeeNewToken -apiKey $apiKey -RefreshToken $Tokens.refresh_token
    Save-EcobeeTokens -Tokens $Tokens

}
else { $Tokens = Import-Clixml -Path $TokenFile }

if ($Tokens.expiree_at -lt (Get-Date)) { $Tokens = Get-EcobeeNewToken -RefreshToken $Tokens.refresh_token -apiKey $apikey; Save-EcobeeTokens -Tokens $Tokens }
$EcobeeDetails = Get-EcobeeDetails -AccessToken $Tokens.access_token

#endregion Ecobee App Registration and Data Retrieval

#region Influx data conversion & writes

## Adding a property here under the proper category will add it to the metrics
$Include = New-Object -TypeName PSObject -Property @{
    Settings = "lastServiceDate","remindMeDate","coldTempAlert","hotTempAlert"
    Runtime = "runtimeInterval","actualTemperature","actualHumidity","desiredHeat","desiredCool","desiredHumidity","desiredDehumidity"
    Weather = "weatherStation"
    ## Categories should contain the names of the above properties
    Categories = "Settings","Runtime","Weather"
}

$Timestamp = Get-Date
[int64]$epochnanoseconds = [Double](Get-Date $Timestamp.ToUniversalTime() -UFormat %s) * 1000000000

$InfluxData = "" # Create an empty string

foreach ($Thermostat in $EcobeeDetails.thermostatList) {
    
    # Values that never change as tags
    $CommonData = "$InfluxTable,$($GlobalTags),name=$($Thermostat.name),id=$($Thermostat.identifier),model=$($Thermostat.modelNumber)" -Replace '(\s)', '\$1'
    
    $InfluxData += "$CommonData revision=$($Thermostat.thermostatRev) $epochnanoseconds`n"
    $InfluxData += "$CommonData equipmentStatus=""$($Thermostat.equipmentStatus)"" $epochnanoseconds`n"
    $InfluxData += "$CommonData eventCount=$($Thermostat.events.Count) $epochnanoseconds`n"
    $InfluxData += "$CommonData reminedMeCountdownMS=$([int64](([datetime]$thermostat.settings.remindMeDate) - (get-date)).totalMilliseconds) $epochnanoseconds`n"

    foreach ($Category in $Include.Categories) {
        foreach ($Property in $Include.$Category) {
           # Fill in a dummy value instead of a null
           if ($Thermostat.$Category.$Property -eq $null) { $Thermostat.$Category.$Property = 0 }
   
           # Values of type=string need quotes when sent to Influx
           if ($Thermostat.$Category.$Property.GetType().name -like "String") {
               $InfluxData+=  "$CommonData,Category=$Category $($Property)=""$($Thermostat.$Category.$Property)"" $epochnanoseconds`n"
           }

           # Values of type=int or boolean need NO quotes when sent to Influx
           else {
               $InfluxData+= "$CommonData,Category=$Category $($Property)=$($Thermostat.$Category.$Property) $epochnanoseconds`n"
           }
       } # End foreach $Property
   } # End foreach $Category
    foreach ($Event in $Thermostat.events) { 
        <# Do nothing here yet #> 
    }
    foreach ($Sensor in $Thermostat.remoteSensors) {
        $id = $Sensor.id
        $SensorTags = "sensorID=$($Sensor.id),sensorName=$($Sensor.name),sensorType=$($Sensor.type)" -Replace '(\s)', '\$1'
        $InfluxData+=  "$CommonData,Category=Sensors,$SensorTags inUse=$($Sensor.inUse) $epochnanoseconds`n"
        foreach ($Capability in $Sensor.capability) {
            if ($Capability.value -eq $null) { $Capability.value = 0 }
            $InfluxData+= "$CommonData,Category=Sensors,$SensorTags $($capability.type)=$($Capability.value) $epochnanoseconds`n"
        }
    }
    $Weather = $Thermostat.weather.forecasts[0]
    $Properties = "weatherSymbol","dateTime","condition","temperature","pressure","relativeHumidity","dewpoint","visibility","windSpeed","windGust","windDirection","windBearing","pop","tempHigh","tempLow","sky"
    foreach ($Property in $Properties) {
        $WeatherTags = "Category=Weather,sensorID=$($Thermostat.weather.weatherStation),sensorName=WeatherStation,sensorType=station" -Replace '(\s)', '\$1'
        if ($Weather.$Property.GetType().name -like "String") {
            $InfluxData+= "$CommonData,$WeatherTags $($Property)=""$($Weather.$Property)"" $epochnanoseconds`n"
        }
        else {
            $InfluxData+= "$CommonData,$WeatherTags $($Property)=$($Weather.$Property) $epochnanoseconds`n"
        }
    }
    foreach ($Day in $Thermostat.weather.forecasts) {
        #TODO
    }
 

} # End foreach $Thermostat


# Write data to InfluxDB

if ($InfluxAuthentication) {
    try {
        Invoke-RestMethod -Headers @{Authorization=$AuthString} -URI "$InfluxHost/write?db=$InfluxDBName" -Method POST -Body $InfluxData -ContentType 'application/json'
    } catch { Write-Error "There was a problem writing data to the InfluxDB API: $InfluxHost Authentication=True" }
}
Else {
    try {
        Invoke-RestMethod -URI "$InfluxHost/write?db=$InfluxDBName" -Method POST -Body $InfluxData -ContentType 'application/json'
    } catch { Write-Error "There was a problem writing data to the InfluxDB API: $InfluxHost Authentication=False" }
}

# if Invoke-Restmethod returns {"error":"database not found"}
# Invoke-RestMethod -Headers @{Authorization=$AuthString} -URI "$InfluxHost/query?q=CREATE DATABASE $InfluxDBName" -Method POST  -ContentType 'application/json'

#endregion Influx data conversion & writes
