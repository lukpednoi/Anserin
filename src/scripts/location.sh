#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/config.sh"

export LC_ALL=C

VERBOSE=false
FORCE_REFRESH=false

for arg in "$@"; do
    if [[ "$arg" == "--verbose" || "$arg" == "-v" ]]; then
        VERBOSE=true
    elif [[ "$arg" == "--refresh" || "$arg" == "-r" ]]; then
        FORCE_REFRESH=true
    fi
done

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "\e[1;34m[LOCATION-DEBUG]\e[0m $1" >&2
    fi
}

get_existing_location() {
    local gen
    gen="$(get_setting "general" '{}')"
    echo "$gen" | jq -c '.location // empty' 2>/dev/null
}

save_location() {
    local loc_data="$1"
    local gen
    gen="$(get_setting "general" '{}')"
    local updated
    updated="$(echo "$gen" | jq --argjson loc "$loc_data" '.location = $loc')"
    set_setting "general" "$updated"
    "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/weather.sh" --getdata >/dev/null 2>&1 &
}

try_wifi_location() {
    command -v nmcli >/dev/null 2>&1 || return 1
    [[ "$(nmcli radio wifi 2>/dev/null)" == "enabled" ]] || return 1
    log_debug "Looking up nearby Wi-Fi access points with beaconDB (IP fallback disabled)..."
    local request resp lat lon place
    # Skip opt-out networks and randomized MAC addresses unsuitable for locating fixed access points.
    request=$(nmcli --terse --escape no --fields BSSID,SIGNAL,SSID device wifi list --rescan yes 2>/dev/null | jq -R -s '
        split("\n") | map(
            split(":") | select(length >= 8) |
            {macAddress: (.[0:6] | join(":") | ascii_downcase),
             signalStrength: ((.[6] | tonumber? // -1) / 2 - 100 | round),
             ssid: (.[7:] | join(":"))} |
            select(.ssid != "" and .ssid != "--" and (.ssid | endswith("_nomap") | not)) |
            select(.macAddress | test("^[0-9a-f][048c](:[0-9a-f]{2}){5}$")) |
            select(.signalStrength >= -100 and .signalStrength <= -50) | del(.ssid)
        ) | unique_by(.macAddress) |
        {considerIp: false, fallbacks: {ipf: false, lacf: false}, wifiAccessPoints: .}
    ') || return 1
    jq -e '.wifiAccessPoints | length >= 2' <<< "$request" >/dev/null || return 1
    resp=$(curl -fsS --max-time 10 -H 'Content-Type: application/json' \
        -H 'User-Agent: anserin-location/1.0' --data-binary "$request" \
        'https://api.beacondb.net/v1/geolocate' 2>/dev/null) || return 1
    if ! jq -e '
        (.location.lat | type) == "number" and (.location.lng | type) == "number" and
        .location.lat >= -90 and .location.lat <= 90 and
        .location.lng >= -180 and .location.lng <= 180 and
        (.accuracy | type) == "number" and .accuracy >= 0 and .fallback == null
    ' <<< "$resp" >/dev/null 2>&1; then
        return 1
    fi
    lat=$(jq -r '.location.lat' <<< "$resp")
    lon=$(jq -r '.location.lng' <<< "$resp")
    place=$(curl -fsS --max-time 5 \
        "https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lon}&localityLanguage=en" 2>/dev/null)
    if ! jq -e 'type == "object"' <<< "$place" >/dev/null 2>&1; then place='{}'; fi
    jq --argjson place "$place" '
        {latitude: .location.lat, longitude: .location.lng, accuracy: .accuracy,
         city: ($place.city // $place.locality // (.location.lat | tostring) + ", " + (.location.lng | tostring)),
         region: ($place.principalSubdivision // "Unknown"),
         country_name: ($place.countryName // "Unknown"), country_code: ($place.countryCode // ""),
         timezone: "auto", source: "beacondb-wifi"}
    ' <<< "$resp"
}

try_ipapi() {
    log_debug "Attempting primary provider: ipapi.co..."
    local resp
    resp="$(curl -s --max-time 5 -H "User-Agent: anserin-location/1.0" "https://ipapi.co/json/" 2>/dev/null)"
    if echo "$resp" | jq -e '(.error | not) and .latitude != null and .longitude != null' >/dev/null 2>&1; then
        echo "$resp" | jq -c '{
            ip: (.ip // null),
            latitude: .latitude,
            longitude: .longitude,
            city: (.city // "Unknown"),
            region: (.region // "Unknown"),
            region_code: (.region_code // null),
            country_name: (.country_name // "Unknown"),
            country_code: (.country_code // null),
            postal: (.postal // null),
            timezone: (.timezone // "UTC"),
            utc_offset: (.utc_offset // null),
            currency: (.currency // null),
            languages: (.languages // null),
            asn: (.asn // null),
            org: (.org // null),
            source: "ipapi.co"
        }'
        return 0
    fi
    return 1
}

try_ip_api_com() {
    log_debug "ipapi.co failed or rate-limited. Falling back to ip-api.com..."
    local resp
    resp="$(curl -s --max-time 5 "http://ip-api.com/json/?fields=status,message,query,lat,lon,city,regionName,region,country,countryCode,zip,timezone,currency,as,org" 2>/dev/null)"
    if echo "$resp" | jq -e '.status == "success" and .lat != null and .lon != null' >/dev/null 2>&1; then
        echo "$resp" | jq -c '{
            ip: (.query // null),
            latitude: .lat,
            longitude: .lon,
            city: (.city // "Unknown"),
            region: (.regionName // "Unknown"),
            region_code: (.region // null),
            country_name: (.country // "Unknown"),
            country_code: (.countryCode // null),
            postal: (.zip // null),
            timezone: (.timezone // "UTC"),
            utc_offset: null,
            currency: (.currency // null),
            languages: null,
            asn: (.as // null),
            org: (.org // null),
            source: "ip-api.com"
        }'
        return 0
    fi
    return 1
}

try_ipwhois() {
    log_debug "ip-api.com failed. Falling back to ipwho.is..."
    local resp
    resp="$(curl -s --max-time 5 "https://ipwho.is/" 2>/dev/null)"
    if echo "$resp" | jq -e '.success == true and .latitude != null and .longitude != null' >/dev/null 2>&1; then
        echo "$resp" | jq -c '{
            ip: (.ip // null),
            latitude: .latitude,
            longitude: .longitude,
            city: (.city // "Unknown"),
            region: (.region // "Unknown"),
            region_code: (.region_code // null),
            country_name: (.country // "Unknown"),
            country_code: (.country_code // null),
            postal: (.postal // null),
            timezone: (.timezone.id // "UTC"),
            utc_offset: (.timezone.utc // null),
            currency: (.connection.currency // null),
            languages: null,
            asn: ((.connection.asn | tostring) // null),
            org: (.connection.org // null),
            source: "ipwho.is"
        }'
        return 0
    fi
    return 1
}

fetch_ip_location() {
    local res
    if res="$(try_ipapi)" && [[ -n "$res" ]]; then
        echo "$res"
        return 0
    fi
    if res="$(try_ip_api_com)" && [[ -n "$res" ]]; then
        echo "$res"
        return 0
    fi
    if res="$(try_ipwhois)" && [[ -n "$res" ]]; then
        echo "$res"
        return 0
    fi
    return 1
}

resolve_location() {
    local existing
    existing="$(get_existing_location)"

    local source
    source="$(echo "$existing" | jq -r '.source // empty' 2>/dev/null)"

    if [[ "$source" == "manual" && "$FORCE_REFRESH" == "false" ]]; then
        echo "$existing"
        return
    fi

    if [[ "$FORCE_REFRESH" == "false" && -n "$existing" && "$existing" != "null" ]]; then
        local updated_at current_time diff
        updated_at=$(echo "$existing" | jq -r '.updated_at // 0')
        current_time=$(date +%s)
        diff=$((current_time - updated_at))
        log_debug "Found location in config. Age: $diff seconds."
        if [ $diff -lt 900 ]; then
            log_debug "Config location is fresh. Returning existing data."
            echo "$existing"
            return
        fi
    fi

    log_debug "Fetching location details..."
    local raw_loc
    raw_loc="$(try_wifi_location)"
    if [[ -z "$raw_loc" ]]; then
        log_debug "Wi-Fi location unavailable. Using approximate IP location."
        raw_loc="$(fetch_ip_location)"
    fi

    if [[ -n "$raw_loc" && "$raw_loc" != "null" ]]; then
        log_debug "Geolocation retrieved successfully."
        local now
        now=$(date +%s)
        local final_loc
        final_loc=$(echo "$raw_loc" | jq --argjson ts "$now" '. + {updated_at: $ts}')
        # a place locked while this was looking (Location → Apply) stays; only Auto-detect replaces it
        if [[ "$FORCE_REFRESH" == "false" && "$(get_existing_location | jq -r '.source // empty' 2>/dev/null)" == "manual" ]]; then
            get_existing_location
            return
        fi
        save_location "$final_loc"
        echo "$final_loc"
    elif [[ -n "$existing" && "$existing" != "null" ]]; then
        log_debug "All providers failed. Falling back to existing config location."
        echo "$existing"
    else
        log_debug "No location data or config available. Defaulting to fallback payload."
        local fallback
        fallback='{"latitude": 0.0, "longitude": 0.0, "city": "Unknown", "region": "Unknown", "country_name": "Unknown", "timezone": "UTC", "updated_at": 0}'
        save_location "$fallback"
        echo "$fallback"
    fi
}


resolve_location
