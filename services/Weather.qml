pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtPositioning

import qs.modules.common

Singleton {
    id: root

    readonly property bool enabled: Config.options?.bar?.weather?.enable ?? false
    readonly property int fetchInterval: (Config.options?.bar?.weather?.fetchInterval ?? 10) * 60 * 1000
    readonly property string city: Config.options?.bar?.weather?.city ?? ""
    readonly property bool useUSCS: Config.options?.bar?.weather?.useUSCS ?? false
    property bool gpsActive: Config.options?.bar?.weather?.enableGPS ?? false

    // GPS is started when gpsActive becomes true and weather is enabled
    onGpsActiveChanged: {
        if (root.gpsActive && root.enabled && !positionSource.active) {
            console.info("[WeatherService] Starting GPS service.")
            positionSource.start()
        }
    }

    onEnabledChanged: {
        if (root.enabled) {
            console.info("[WeatherService] Weather enabled")
            if (root.gpsActive && !positionSource.active) {
                console.info("[WeatherService] Starting GPS.")
                positionSource.start()
            }
            // Trigger initial fetch if Config is already ready
            // This handles the race condition where Config.ready fires before enabled propagates
            if (Config.ready && !root.location.valid) {
                console.info("[WeatherService] Config already ready, triggering initial fetch")
                Qt.callLater(() => root.getData())
            }
        }
    }

    onUseUSCSChanged: root.getData()
    onCityChanged: root._geocodeCity()

    Connections {
        target: Config
        function onReadyChanged(): void {
            if (Config.ready && root.enabled) {
                console.info("[WeatherService] Config ready, fetching weather data")
                if (root.gpsActive && !positionSource.active) {
                    positionSource.start()
                }
                Qt.callLater(() => root.getData())
            }
        }
    }

    property var location: ({ valid: false, lat: 0, lon: 0, name: "" })

    property var data: ({
        uv: "0",
        humidity: "0%",
        sunrise: "--:--",
        sunriseIso: "",
        sunset: "--:--",
        sunsetIso: "",
        windDir: "N",
        wCode: "0",
        city: "City",
        wind: "0 km/h",
        precip: "0 mm",
        visib: "10 km",
        press: "1013 hPa",
        temp: "--°C",
        tempFeelsLike: "--°C"
    })
    
    // Forecast for next days: [{date, tempMax, tempMin, wCode, chanceOfRain, description}]
    property var forecast: []

    function isNightNow(): bool {
        const now = new Date();

        const sunriseIso = root.data?.sunriseIso ?? "";
        const sunsetIso = root.data?.sunsetIso ?? "";
        if (sunriseIso.length > 0 && sunsetIso.length > 0) {
            const sunrise = new Date(sunriseIso);
            const sunset = new Date(sunsetIso);
            if (!isNaN(sunrise.getTime()) && !isNaN(sunset.getTime())) {
                return now < sunrise || now > sunset;
            }
        }

        const h = now.getHours();
        return h < 6 || h >= 18;
    }

    // WMO Weather codes to wttr.in codes (for icon compatibility)
    function _wmoToWttr(code: int): string {
        const map = {
            "0": "113",    // Clear sky
            "1": "116", "2": "116", "3": "119",  // Partly cloudy, cloudy
            "45": "143", "48": "143",  // Fog
            "51": "266", "53": "266", "55": "266",  // Drizzle
            "56": "281", "57": "281",  // Freezing drizzle
            "61": "296", "63": "302", "65": "308",  // Rain
            "66": "311", "67": "314",  // Freezing rain
            "71": "326", "73": "329", "75": "332",  // Snow
            "77": "350",  // Snow grains
            "80": "353", "81": "356", "82": "359",  // Rain showers
            "85": "368", "86": "371",  // Snow showers
            "95": "386",  // Thunderstorm
            "96": "389", "99": "395"   // Thunderstorm with hail
        };
        return map[String(code)] ?? "113";
    }

    function _degToCompass(deg: real): string {
        const dirs = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                      "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
        return dirs[Math.round(deg / 22.5) % 16];
    }

    function _formatTime(isoTime: string): string {
        if (!isoTime) return "--:--";
        const date = new Date(isoTime);
        return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false });
    }

    function _refineData(apiData: var): void {
        const current = apiData?.current;
        const daily = apiData?.daily;
        if (!current) return;

        let result = {};
        const wmoCode = current.weather_code ?? 0;
        result.wCode = root._wmoToWttr(wmoCode);
        result.city = root.location.name || root.city || "Unknown";
        result.humidity = (current.relative_humidity_2m ?? 0) + "%";
        result.windDir = root._degToCompass(current.wind_direction_10m ?? 0);
        result.press = Math.round(current.surface_pressure ?? 1013) + " hPa";
        result.uv = daily?.uv_index_max?.[0]?.toFixed(1) ?? "0";
        result.sunriseIso = daily?.sunrise?.[0] ?? "";
        result.sunsetIso = daily?.sunset?.[0] ?? "";
        result.sunrise = root._formatTime(result.sunriseIso);
        result.sunset = root._formatTime(result.sunsetIso);

        // Visibility not available in Open-Meteo free tier, use placeholder
        result.visib = "10 km";
        // Precipitation - current doesn't have it, would need hourly
        result.precip = "0 mm";

        if (root.useUSCS) {
            const tempF = Math.round((current.temperature_2m ?? 0) * 9/5 + 32);
            const feelsF = Math.round((current.apparent_temperature ?? 0) * 9/5 + 32);
            const windMph = Math.round((current.wind_speed_10m ?? 0) * 0.621371);
            result.temp = tempF + "°F";
            result.tempFeelsLike = feelsF + "°F";
            result.wind = windMph + " mph";
            result.press = Math.round((current.surface_pressure ?? 1013) * 0.02953) + " inHg";
        } else {
            result.temp = Math.round(current.temperature_2m ?? 0) + "°C";
            result.tempFeelsLike = Math.round(current.apparent_temperature ?? 0) + "°C";
            result.wind = Math.round(current.wind_speed_10m ?? 0) + " km/h";
        }

        root.data = result;
    }

    function _geocodeCity(): void {
        if (!root.city || root.city.length === 0) {
            root._fetchByIP();
            return;
        }
        const cleanCity = root.city.replace(/[\r\n]+/g, '').trim();
        const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(cleanCity)}&count=1&language=en&format=json`;
        geocoder.command = ["/usr/bin/curl", "-s", "--max-time", "10", url];
        geocoder.running = true;
    }

    function _fetchByIP(): void {
        // Avoid duplicate requests
        if (ipLocator.running) return;
        ipLocator.running = true;
    }

    function getData(): void {
        if (!root.location.valid) {
            root._geocodeCity();
            return;
        }

        // Avoid duplicate requests
        if (fetcher.running || fallbackFetcher.running) return;

        const lat = root.location.lat;
        const lon = root.location.lon;
        const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,surface_pressure&daily=sunrise,sunset,uv_index_max&timezone=auto`;

        fetcher.command = ["/usr/bin/curl", "-s", "--max-time", "8", url];
        fetcher.running = true;
    }
    
    function _fetchFallback(): void {
        if (fallbackFetcher.running) return;
        const city = encodeURIComponent(root.location.name || root.city || "auto");
        fallbackFetcher.command = ["/usr/bin/curl", "-s", "--max-time", "10", `https://wttr.in/${city}?format=j1`];
        fallbackFetcher.running = true;
    }
    
    function _refineWttrData(apiData: var): void {
        const current = apiData?.current_condition?.[0];
        const astro = apiData?.weather?.[0]?.astronomy?.[0];
        const weatherDays = apiData?.weather ?? [];
        if (!current) return;

        let result = {};
        result.wCode = current.weatherCode ?? "113";
        result.city = root.location.name || root.city || "Unknown";
        result.humidity = (current.humidity ?? 0) + "%";
        result.windDir = current.winddir16Point ?? "N";
        result.uv = current.uvIndex ?? "0";
        result.visib = (current.visibility ?? 10) + " km";
        result.precip = (current.precipMM ?? 0) + " mm";
        
        // Parse sunrise/sunset times
        result.sunrise = astro?.sunrise?.replace(/\s*(AM|PM)/i, (m, p) => ' ' + p.toUpperCase()) ?? "--:--";
        result.sunset = astro?.sunset?.replace(/\s*(AM|PM)/i, (m, p) => ' ' + p.toUpperCase()) ?? "--:--";
        result.sunriseIso = "";
        result.sunsetIso = "";

        if (root.useUSCS) {
            result.temp = (current.temp_F ?? 0) + "°F";
            result.tempFeelsLike = (current.FeelsLikeF ?? 0) + "°F";
            result.wind = (current.windspeedMiles ?? 0) + " mph";
            result.press = (current.pressureInches ?? 30) + " inHg";
        } else {
            result.temp = (current.temp_C ?? 0) + "°C";
            result.tempFeelsLike = (current.FeelsLikeC ?? 0) + "°C";
            result.wind = (current.windspeedKmph ?? 0) + " km/h";
            result.press = (current.pressure ?? 1013) + " hPa";
        }

        root.data = result;
        
        // Parse forecast (skip today, get next 2 days)
        let forecastList = [];
        for (let i = 1; i < Math.min(weatherDays.length, 4); i++) {
            const day = weatherDays[i];
            const midday = day.hourly?.[4] ?? {}; // 12:00
            const maxRain = Math.max(...(day.hourly?.map(h => parseInt(h.chanceofrain) || 0) ?? [0]));
            
            forecastList.push({
                date: day.date,
                tempMax: root.useUSCS ? day.maxtempF + "°F" : day.maxtempC + "°C",
                tempMin: root.useUSCS ? day.mintempF + "°F" : day.mintempC + "°C",
                wCode: midday.weatherCode ?? "113",
                chanceOfRain: maxRain,
                description: midday.weatherDesc?.[0]?.value ?? ""
            });
        }
        root.forecast = forecastList;
    }

    // Geocoding process
    Process {
        id: geocoder
        command: ["/usr/bin/curl", "-s", "--max-time", "10", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                try {
                    const data = JSON.parse(text);
                    const result = data?.results?.[0];
                    if (result) {
                        root.location = {
                            valid: true,
                            lat: result.latitude,
                            lon: result.longitude,
                            name: result.name + (result.admin1 ? `, ${result.admin1}` : "")
                        };
                        console.info(`[WeatherService] Geocoded: ${root.location.name} (${root.location.lat}, ${root.location.lon})`);
                        root.getData();
                    } else {
                        console.warn("[WeatherService] City not found, falling back to IP location");
                        root._fetchByIP();
                    }
                } catch (e) {
                    console.error(`[WeatherService] Geocoding error: ${e.message}`);
                }
            }
        }
    }

    // IP-based location fallback
    Process {
        id: ipLocator
        command: ["/usr/bin/curl", "-s", "--max-time", "10", "http://ip-api.com/json/?fields=lat,lon,city,regionName"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                try {
                    const data = JSON.parse(text);
                    if (data.lat && data.lon) {
                        root.location = {
                            valid: true,
                            lat: data.lat,
                            lon: data.lon,
                            name: data.city + (data.regionName ? `, ${data.regionName}` : "")
                        };
                        console.info(`[WeatherService] Location: ${root.location.name}`);
                        root.getData();
                    }
                } catch (e) {
                    console.error(`[WeatherService] IP location error: ${e.message}`);
                }
            }
        }
    }

    // Weather data fetcher (primary: open-meteo)
    Process {
        id: fetcher
        property bool _fallbackCalled: false
        command: ["/usr/bin/curl", "-s", "--max-time", "8", ""]
        onRunningChanged: if (running) _fallbackCalled = false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) {
                    if (!fetcher._fallbackCalled) {
                        fetcher._fallbackCalled = true;
                        console.warn("[WeatherService] Open-meteo returned empty, trying fallback");
                        root._fetchFallback();
                    }
                    return;
                }
                try {
                    const data = JSON.parse(text);
                    if (data.error || !data.current) {
                        if (!fetcher._fallbackCalled) {
                            fetcher._fallbackCalled = true;
                            console.warn("[WeatherService] Open-meteo error, trying fallback");
                            root._fetchFallback();
                        }
                        return;
                    }
                    root._refineData(data);
                    console.info("[WeatherService] Updated:", root.data.temp, root.data.city)
                } catch (e) {
                    if (!fetcher._fallbackCalled) {
                        fetcher._fallbackCalled = true;
                        console.warn("[WeatherService] Open-meteo parse error, trying fallback");
                        root._fetchFallback();
                    }
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && !fetcher._fallbackCalled) {
                fetcher._fallbackCalled = true;
                console.warn("[WeatherService] Open-meteo fetch failed (code", code + "), trying fallback");
                root._fetchFallback();
            }
        }
    }
    
    // Weather data fetcher (fallback: wttr.in)
    Process {
        id: fallbackFetcher
        command: ["/usr/bin/curl", "-s", "--max-time", "10", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                try {
                    const data = JSON.parse(text);
                    root._refineWttrData(data);
                    console.info("[WeatherService] Updated (wttr.in):", root.data.temp, root.data.city)
                } catch (e) {
                    console.error("[WeatherService] Fallback fetch error:", e.message);
                }
            }
        }
    }

    PositionSource {
        id: positionSource
        updateInterval: root.fetchInterval

        onPositionChanged: {
            if (position.latitudeValid && position.longitudeValid) {
                root.location = {
                    valid: true,
                    lat: position.coordinate.latitude,
                    lon: position.coordinate.longitude,
                    name: root.city || "GPS Location"
                };
                root.getData();
            } else {
                root.gpsActive = root.location.valid;
                console.error("[WeatherService] Failed to get GPS location.");
            }
        }

        onValidityChanged: {
            if (!positionSource.valid) {
                positionSource.stop();
                root.location.valid = false;
                root.gpsActive = false;
                Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Weather Service"),
                    Translation.tr("Cannot find a GPS service. Using the fallback method instead."), "-a", "Shell"]);
                console.error("[WeatherService] Could not acquire a valid backend plugin.");
                root._geocodeCity();
            }
        }
    }

    Timer {
        id: fetchTimer
        running: root.enabled && Config.ready
        repeat: true
        interval: root.fetchInterval > 0 ? root.fetchInterval : 600000
        // Don't use triggeredOnStart - we handle it in onRunningChanged
        onTriggered: root.getData()
        onRunningChanged: {
            if (running) {
                console.info("[WeatherService] Fetch timer started, interval:", interval / 1000 / 60, "min")
                // Fetch immediately when timer starts
                Qt.callLater(() => root.getData())
            }
        }
    }
}
