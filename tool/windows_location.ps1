$ErrorActionPreference = 'Stop'
try {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  $locator = New-Object 'Windows.Devices.Geolocation.Geolocator, Windows.Devices.Geolocation, ContentType=WindowsRuntime'
  $locator.DesiredAccuracy = [Windows.Devices.Geolocation.PositionAccuracy]::High
  $awaitMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and
    $_.GetGenericArguments().Count -eq 1 -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
  } | Select-Object -First 1
  $operation = $locator.GetGeopositionAsync([TimeSpan]::Zero, [TimeSpan]::FromSeconds(15))
  $task = $awaitMethod.MakeGenericMethod([Windows.Devices.Geolocation.Geoposition]).Invoke($null, @($operation))
  if (!$task.Wait(18000)) { throw 'Windows location timed out' }
  $coordinate = $task.Result.Coordinate
  if ($coordinate.PositionSource.ToString() -eq 'Default') { throw 'Windows returned a default location, not a device fix' }
  if ([DateTimeOffset]::UtcNow.Subtract($coordinate.Timestamp.ToUniversalTime()).TotalSeconds -gt 30) { throw 'Windows returned a stale location' }
  $position = $coordinate.Point.Position
  @{
    latitude = $position.Latitude
    longitude = $position.Longitude
    accuracy = $coordinate.Accuracy
    timestamp = $coordinate.Timestamp.ToUniversalTime().ToString('o')
    source = "Windows $($coordinate.PositionSource)"
  } | ConvertTo-Json -Compress
} catch {
  @{error = 'Windows chưa cung cấp vị trí mới. Kiểm tra dịch vụ và quyền Vị trí của Windows.'} | ConvertTo-Json -Compress
  exit 1
}
