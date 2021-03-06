# Install Chocolatey
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
# Globally Auto confirm every action
choco feature enable -n allowGlobalConfirmation

choco install netfx-4.5.2-devpack
# Install build tools 2015
choco install microsoft-build-tools --version 14.0.25420.1
choco install nuget.commandline
choco install nunit-console-runner
choco install git
