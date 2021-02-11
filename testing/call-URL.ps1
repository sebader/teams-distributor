param
(
  [Parameter(Mandatory)]
  [string]
  ${Please provide the URL to test}
)


$URL   = ${Please provide the URL to test}
$count = 10

function Get-UrlStatusCode([string] $Url)
{
    try
    {
        (Invoke-WebRequest -Uri $Url -UseBasicParsing -DisableKeepAlive).StatusCode
    }
    catch [Net.WebException]
    {
        [int]$_.Exception.Response.StatusCode
    }
}


for($i = 0; $i -lt $count; $i++){ Get-UrlStatusCode $URL }