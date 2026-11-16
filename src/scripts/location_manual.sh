#!/usr/bin/env bash
# Lock the location to a place Mo names: location_manual.sh COUNTRY PROVINCE
# Open-Meteo's geocoding (the weather's own provider) finds the province's main town in that country; the location
# is saved with source "manual", so the Weather round's auto-detect leaves it alone until Auto-detect is pressed.
# Prints one JSON line: {"ok":true} or {"error":"Not found"} (nothing is changed then).

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/config.sh"

trim() { local v="$1"; v="${v#"${v%%[![:space:]]*}"}"; printf '%s' "${v%"${v##*[![:space:]]}"}"; }
country="$(trim "$1")"
province="$(trim "$2")"

if [[ -z "$country" || -z "$province" ]]; then
    echo '{"error":"Not found"}'
    exit 2
fi

res="$(curl -sL --max-time 10 -G "https://geocoding-api.open-meteo.com/v1/search" \
    --data-urlencode "name=$province" -d count=30 -d language=en -d format=json)"
if [[ -z "$res" ]]; then
    echo '{"error":"No connection"}'
    exit 1
fi

# in that country (by name or code); the province's own capital first, then a place of that name, then any in it
pick="$(echo "$res" | jq -c --arg c "$country" --arg p "$province" '
    def low: ascii_downcase;
    [(.results // [])[] | select((.country // "" | low) == ($c | low) or (.country_code // "" | low) == ($c | low))] as $r
    | ([$r[] | select((.admin1 // "" | low) == ($p | low) and ((.feature_code // "") | test("^PPL(A|C)$")))]
       + [$r[] | select((.name // "" | low) == ($p | low))]
       + [$r[] | select((.admin1 // "" | low) == ($p | low))]
       + $r)[0] // empty' 2>/dev/null)"

if [[ -z "$pick" ]]; then
    echo '{"error":"Not found"}'
    exit 2
fi

now=$(date +%s)
json="$(echo "$pick" | jq -c --arg p "$province" --argjson ts "$now" '{
    latitude: .latitude,
    longitude: .longitude,
    city: $p,
    region: $p,
    country_name: .country,
    country_code: ((.country_code // "") | ascii_upcase),
    timezone: (.timezone // "UTC"),
    place_province: $p,
    place_country: .country,
    source: "manual",
    updated_at: $ts
}')"

gen="$(get_setting "general" '{}')"
updated="$(echo "$gen" | jq --argjson loc "$json" '.location = $loc')"
set_setting "general" "$updated"
"$(dirname "$(realpath "${BASH_SOURCE[0]}")")/weather.sh" --getdata >/dev/null 2>&1 &
echo '{"ok":true}'
