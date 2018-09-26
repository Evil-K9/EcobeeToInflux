# EcobeeToInflux
Powershell code for communicating with the Ecobee API to retrieve metrics, and then feed it to InfluxDB

You'll need to [sign up with Ecobee as a developer](https://www.ecobee.com/home/developer/api/introduction/index.shtml), create an app wich any name you like, then copy your new API key and paste it into the $api variable in the script.
Run the script once manually to generate the PIN for you to add to your Ecobee "My Apps" list.

After it has generated the tokens, it ran run repeatedly. Ecobee states that you should not run an API call more frequent than 3 minutes apart, and that your Ecobee only updates stats every 15 minutes anyway. 

I suggest having the script run like this:
````PowerShell
while ($True) { .\ecobee.ps1; Start-Sleep -Seconds 900; }

````
Where 900 seconds equals 15 minutes.

Or add it as a scheduled task. But be sure to run it manually the first time to get your tokens.
