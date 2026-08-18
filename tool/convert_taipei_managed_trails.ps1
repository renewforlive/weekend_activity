param(
  [Parameter(Mandatory = $true)]
  [string]$InputCsv,
  [string]$OutputJson = 'assets/data/taipei_managed_trails.json'
)

# 台北市開放資料為 Big5 CSV，且有一筆合法的引號內換行；必須以整份文字
# 交給 ConvertFrom-Csv，不能逐行管線處理，否則該筆步道會被拆壞。
$encoding = [System.Text.Encoding]::GetEncoding(950)
$raw = [System.IO.File]::ReadAllText($InputCsv, $encoding)
$rows = @($raw | ConvertFrom-Csv)

$difficulty = @{
  '親子級' = '1'
  '勇腳級' = '3'
}

$trails = foreach ($row in $rows) {
  $name = ($row.'登山步道路線' ?? '').Trim() -replace '[\r\n]+', ' '
  if ([string]::IsNullOrWhiteSpace($name)) { continue }

  $lengthMeters = [double]::TryParse($row.'總長M', [ref]$null)
  $meters = if ($lengthMeters) { [double]$row.'總長M' } else { 0 }
  $minutes = 0
  [void][int]::TryParse($row.'單程步行時間min', [ref]$minutes)
  $district = ($row.'行政區' ?? '').Trim()
  $start = ($row.'起點' ?? '').Trim()
  $end = ($row.'迄點' ?? '').Trim()

  [pscustomobject]@{
    TRAILID = ('taipei-managed-{0:d3}' -f [int]$row.'序號')
    TR_CNAME = $name
    TR_POSITION = "台北市$district"
    TR_DIF_CLASS = if ($difficulty.ContainsKey($row.'步道分級')) { $difficulty[$row.'步道分級'] } else { '2' }
    TR_LENGTH_NUM = [math]::Round($meters / 1000, 3)
    TR_ALT = 0
    TR_ALT_LOW = 0
    TR_TOUR = if ($minutes -gt 0) { "約$minutes 分鐘" } else { '' }
    TR_BEST_SEASON = ''
    TR_PAVE = "起點階梯：$($row.'起點是否為階梯')；迄點階梯：$($row.'迄點是否為階梯')"
    GUIDE_CONTENT = "起點：$start`n迄點：$end`n行動電話通訊：$($row.'行動電話通訊情形')"
    TR_MAIN_SYS = '臺北市列管登山步道'
    TR_ADMIN = '臺北市政府工務局大地工程處'
    TR_ADMIN_PHONE = ''
    TR_permit = '無'
    URL = ''
    TAIPEI_TRAIL_METADATA = [ordered]@{
      serial = $row.'序號'
      classification = $row.'步道分級'
      start = $start
      startLongitude = $row.'起點經度座標'
      startLatitude = $row.'起點緯度座標'
      end = $end
      endLongitude = $row.'迄點經度座標'
      endLatitude = $row.'迄點緯度座標'
      hasEntranceBarrier = $row.'步道口是否有路擋'
      wheelchairAccessible = $row.'是否適合輪椅通行'
      wheelchairSlope = $row.'輪椅可通行段平均坡度'
      wheelchairLengthMeters = $row.'輪椅可通行段長度M'
      mobileSignal = $row.'行動電話通訊情形'
      hasPortableToilet = $row.'是否有流動廁所'
      portableToiletLocation = $row.'流動廁所位置'
      accessibleToilet = $row.'是否為無障礙廁所'
    }
  }
}

$directory = Split-Path -Parent $OutputJson
if ($directory) { New-Item -ItemType Directory -Force $directory | Out-Null }
$trails | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputJson -Encoding utf8
Write-Output "Converted $(@($trails).Count) Taipei managed trails to $OutputJson"
