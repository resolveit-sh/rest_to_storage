# restapi v01 

#powershell permit self-signed
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

# https://stackoverflow.com/questions/11696944/powershell-v3-invoke-webrequest-https-error/15841856#15841856
# end of self signed 


# should be set manually
$IP="please_insert_ip" 
$Login = "please_insert_login"
$Password = "please_insert_password" 


$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Login,$Password)))

$RestApi01 = "https://${IP}:8088/deviceManager/rest/"
$RestApi02 = "https://${IP}:8088/deviceManager/rest/xxxxx/sessions"

$body = @{username = $Login; password = $Password; scope = 0}
$bodyJson = ConvertTo-Json $body

# Login session
$Logonsession = Invoke-RestMethod -Method Post -Uri $RestApi02 -Body $bodyJson -ContentType "application/json" -SessionVariable WebSession

if ($Logonsession -and $Logonsession.data) {
    $Sessionid = $Logonsession.data.deviceid
    $iBaseToken = $Logonsession.data.iBaseToken
    Write-Host "Session ID: $Sessionid"
} else {
    Write-Host "Login session failed"
    return
}

# Headers
$header = @{ 
    Authorization = "Basic $base64AuthInfo"; 
    iBaseToken = $iBaseToken 
}
$admhuawei = New-Object System.Management.Automation.PsCredential($Login, $(ConvertTo-SecureString -String $Password -AsPlainText -force)) 

# Query Controller Information
$RestApiGetCRTL0A = "https://${IP}:8088/deviceManager/rest/${Sessionid}/controller/0A"

$FW0A = Invoke-RestMethod -Method Get -Uri $RestApiGetCRTL0A -Headers $header -ContentType "application/json" -Credential $admhuawei -WebSession $WebSession
$FW0A | Get-Member
$FW0A.error.code
$FW0A.error.description

$FW0A.data.CPUINFO
$FW0A.data.LOGICVER

# Query Basic System Information
$RestApiGetSystem = "https://${IP}:8088/deviceManager/rest/${Sessionid}/system/"
$FWSystem = Invoke-RestMethod -Method Get -Uri $RestApiGetSystem -Headers $header -ContentType "application/json" -Credential $admhuawei -WebSession $WebSession

$FWSystem.data.PRODUCTVERSION
$FWSystem.data.patchVersion
