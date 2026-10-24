# Browser location QA inputs

These files are test utilities, outside `web/` and Flutter assets. They must not ship as part of the app.

`location.html` replaces only the browser's geolocation input for this fixture page, before the real Flutter bootstrap starts. It uses public museum coordinates, clearly labeled on screen. Photon and OSRM requests are still live. Modes: `success`, `denied`, `unavailable`, `timeout`.

```powershell
flutter build web --release --no-wasm-dry-run
Copy-Item tool/browser_fixtures/location.html build/web/qa-location.html
python -m http.server 53579 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:53579/qa-location.html?mode=success` in the test browser; click the app location control. Navigate to the documented other modes to check each failure. Use a separate test port/origin rather than changing the real app's browser permissions. Stop the QA server, then remove the generated `build/web/qa-location.html` file before delivering the web output.

`location_probe.html` reads secure-context and permission metadata, then requests one real browser fix only when its button is clicked. It displays no latitude/longitude and sends no coordinates to map providers. It uses a proper browser timeout in milliseconds and clears the watch. Serve on the **same origin as the app** when diagnosing the browser's actual page permission. Remove its generated copy after QA as well.

Fixtures prove app behavior for known inputs; they do not certify physical GPS, location accuracy or operating-system permission availability. See `docs/QA_QC.md` for the recorded results.
