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

# Running on Linux

[Powershell is also available for Linux](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-6),
and can be installed directly in most distributions or run with Docker.

First, clone this repository to `/etc/ecobee`. Run the script once to
authenticate against the API with:

```
sudo docker run --network=host \
  --rm -it \
  -v $(pwd):/ecobee \
  mcr.microsoft.com/powershell \
  pwsh ./ecobee/ecobee.ps1
```

Then, add the following file to gather statistics every 15 minutes.

`/etc/cron.d/ecobee-influx:`

```
*/15 * * * *     root  /usr/bin/docker run --network=host --rm -v /etc/ecobee:/ecobee mcr.microsoft.com/powershell pwsh ./ecobee/ecobee.ps1 > /dev/null
```

If powershell is installed directly through a PPA, remove all of the docker
commands and flags and run `pwsh` directly.
