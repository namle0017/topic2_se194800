$ErrorActionPreference = 'Stop'
$qaRoutes = @(
  @{Name='TP.HCM local';From='106.7033,10.7767';To='106.7218,10.7951'},
  @{Name='Ha Noi local';From='105.85,21.03';To='105.83,21.04'},
  @{Name='Da Nang to Hoi An';From='108.22,16.06';To='108.33,15.88'},
  @{Name='TP.HCM to Ha Noi';From='106.7,10.8';To='105.85,21.03'},
  @{Name='Offshore no-road recovery';From='106.7,10.8';To='108.9,10.8'}
)
$qaResults = @()
foreach ($qaRoute in $qaRoutes) {
  $qaWatch = [Diagnostics.Stopwatch]::StartNew()
  $qaUrl = 'https://router.project-osrm.org/route/v1/driving/' + $qaRoute.From + ';' + $qaRoute.To + '?overview=full&geometries=geojson&steps=false&alternatives=false&radiuses=200;200'
  try {
    $qaResponse = Invoke-WebRequest -Uri $qaUrl -Headers @{Origin='http://127.0.0.1:52341'} -TimeoutSec 15 -SkipHttpErrorCheck
    $qaData = $qaResponse.Content | ConvertFrom-Json
    $qaResult = [ordered]@{Name=$qaRoute.Name;HttpStatus=$qaResponse.StatusCode;Code=$qaData.code;Milliseconds=$qaWatch.ElapsedMilliseconds;Cors=$qaResponse.Headers['Access-Control-Allow-Origin']}
    if ($qaData.code -eq 'Ok') {
      $qaRouteData = $qaData.routes[0]
      $qaKm = $qaRouteData.distance / 1000
      $qaRawFare = 30500 + [Math]::Min([Math]::Max($qaKm-2,0),10)*15200 + [Math]::Min([Math]::Max($qaKm-12,0),13)*14700 + [Math]::Max($qaKm-25,0)*13300
      $qaResult.Meters=$qaRouteData.distance
      $qaResult.Seconds=$qaRouteData.duration
      $qaResult.Points=$qaRouteData.geometry.coordinates.Count
      $qaResult.ReferenceFareVnd=[Math]::Ceiling($qaRawFare/1000)*1000
    }
  } catch { $qaResult=[ordered]@{Name=$qaRoute.Name;Milliseconds=$qaWatch.ElapsedMilliseconds;Error=$_.Exception.Message} }
  $qaResults += [pscustomobject]$qaResult
  $qaResult | ConvertTo-Json -Compress
  Start-Sleep -Milliseconds 1100
}
$qaResults | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath docs/live-route-qa-2026-10-06.json -Encoding utf8
