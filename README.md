#  PowerShell для управления CХД Huawei

Для форматирования скрипта рекомендуется использовать PowerShell ISE

Создадим на массиве пользователя:

- **Пользователь**: `api_read`
- **Тип**: Пользователь только для чтения
- **Область**: Локальный пользователь


## Авторизация

### Документация

> `${deviceID}` указывает на уникальный идентификатор устройства. После успешного входа пользователя в клиент и его аутентификации система возвращает это значение. Это значение будет частью URI путей во всех последующих запросах.

**Интерфейс для получения доступа**

**Функция**

Этот интерфейс используется для аутентификации доступа на основе имени пользователя, пароля и типа пользователя. 
Также возвращает информацию о пользователе + идентификатор сеанса после успешного входа пользователя.

**URI**

```
https://${ip}:${port}/deviceManager/rest/xxxxx/sessions
```

Сначала разрешим подключаться с самоподписанными сертификатами:

```powershell
# Разрешение самоподписанных сертификатов

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
# Конец настройки самоподписанных сертификатов
```

Затем зададим переменные:

```powershell
$IP = "insert_ip"
$Login = "insert_login"
$Password = "insert_pass" # Замените на ваш пароль
```

Определим URI для REST API:

```powershell
$RestApi01 = "https://$IP:8088/deviceManager/rest/"
$RestApi02 = "https://$IP:8088/deviceManager/rest/xxxxx/sessions"
```

Сформируем массив для авторизации и переведем его в JSON:

```powershell
$body = @{
    username = $Login
    password = $Password
    scope = 0 # Если используете AD пользователя, то 1, иначе 0
}
$bodyJson = $body | ConvertTo-Json
```

Подключимся к СХД OceanStor и посмотрим, что он нам отдает при авторизации. Сразу добавим `-SessionVariable WebSession`:

```powershell
$logonsession = Invoke-RestMethod -Method Post -Uri $RestApi02 -Body $bodyJson -SessionVariable WebSession
Write-Host $logonsession
Write-Host "-------"
$logonsession | Get-Member
```

Получаем ответ вида:

```
@{data=; error=}
-------
   TypeName: System.Management.Automation.PSCustomObject

Name        MemberType   Definition
----        ----------   ----------
Equals      Method       bool Equals(System.Object obj)
GetHashCode Method       int GetHashCode()
GetType     Method       type GetType()
ToString    Method       string ToString()
data        NoteProperty System.Management.Automation.PSCustomObject data=@{accountstate=1; deviceid=210235843910E6000009; iBaseToken=...}
error       NoteProperty System.Management.Automation.PSCustomObject error=@{code=0; description=0}
```

В итоге из переменной `$logonsession` нам нужен параметр:

```powershell
$sessionid = $logonsession.data.deviceid
```

Который, кстати, соответствует серийному номеру массива.

## Получение информации о версии ПО на массиве

Подготовим заголовки и учетные данные:

```powershell
# Подготовка заголовков
$header = @{
    Authorization = "Basic $base64AuthInfo"
    iBaseToken = $logonsession.data.iBaseToken
}
$admhuawei = New-Object System.Management.Automation.PSCredential(
    $Login,
    (ConvertTo-SecureString -String $Password -AsPlainText -Force)
)
```

### Получение информации о контроллере

Запрос:

```
GET /deviceManager/rest/$sessionid/controller/0A
```

Сформируем URI и выполним запрос:

```powershell
$RestApiGetCRTL0A = "https://$IP:8088/deviceManager/rest/$sessionid/controller/0A"

$FW0A = Invoke-RestMethod -Method Get -Uri $RestApiGetCRTL0A -Headers $header -ContentType "application/json" -Credential $admhuawei -WebSession $WebSession

$FW0A | Get-Member
$FW0A.error.code
$FW0A.error.description

$FW0A.data.CPUINFO
$FW0A.data.LOGICVER
```

### Получение базовой информации о системе 

Сформируем URI и выполним запрос:

```powershell
$RestApiGetSystem = "https://$IP:8088/deviceManager/rest/$sessionid/system/"

$FWSystem = Invoke-RestMethod -Method Get -Uri $RestApiGetSystem -Headers $header -ContentType "application/json" -Credential $admhuawei -WebSession $WebSession

$FWSystem.data.PRODUCTVERSION
$FWSystem.data.patchVersion
```
