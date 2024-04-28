"""
Applet: Toronto BikeShare
Summary: Toronto Bike Share
Description: Shows the availability of bikes and e-bikes at a Toronto Bike Share station.
Author: Jeff Aschkinasi
"""



load("cache.star", "cache")
load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

STATIONS_URL = "https://tor.publicbikesystem.net/ube/gbfs/v1/en/station_information.json"
STATUS_URL = "https://tor.publicbikesystem.net/ube/gbfs/v1/en/station_status.json"

DEFAULT_STATION = '{ "display": "Queen St E / Rhodes Ave", "value": "7309"}'

IMAGE_BICYCLE = base64.decode("iVBORw0KGgoAAAANSUhEUgAAACgAAAAYCAYAAACIhL/AAAAAAXNSR0IArs4c6QAAAdZJREFUWEfNlr9KA0EQxvdKwYewsLZKYxqFCILxBSzE1spGbAQLCdiENFa2Vr6AWhnUJjZWPoEPIYhVZBa/ZRxnd2dOE7zq7tiZ/e03/7YJ//xp5sg3DSG493MbeA90dHhCYGE4GsC0oX/D0cC0t2mRF0quB+QX6GwB5WZWeLLrb22Em9u7aDITBTkcB7Nu9jB+nK731lxRcy3mUG02Ixvy4YGcG+Db8VKEe+5dxnNaIVVAOOOKLZ69flvrUYP7+xUgd9Ttria+yeQpvXNQa5jhF7Zk1xnvJZ+nH7vZwkmqwAkHkxUKUKhgCRX5JZ9kS4D0ramY6w4R0AIH2POF/ZRDtTADjgxetq8iHL0TaE591tgjWwIsKSfhEJ7SRiU48lc6HIeMgNroWbneiaeVcAfvF/EXQqYpwSMilbO2KjDFsVPq7DgprQGcBOS5yAsNRUH/ZBewqlidiwTIwaDA5v1yGldQUYNDjmuAgMz1RBKvCFjLE4w42TYkTOn2UmpVVUCtYcvWI781pTzXK+7vzwFzYazluXZo2FSLJGdsvcHA3qtiqmK0mVIlS9mta9va/eiDVsg2ofJCqpOEhwHvPIRtb9Gl3JJRKM5i6Ui7OXtzrlbt1j0+ATD6iBxXHvA3AAAAAElFTkSuQmCC")

IMAGE_LIGHTNING = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAAp/s
AAKf7ATxDYQ0AAAMySURBVFhHtZZPSFRRFMbPueMfjApcRH8giAiCqNSZ/mlWFGKBFZqaWBS1aRFtgmiXJW6kldCmRdEqcHTIEa
uFYFGZBTojmZuiIlpERASBWfGce/rezG3CZubNe+Prt3lzvufwnfvdc+/I9B+Q25vKpbS4Fx9XcnO8gpkk9SYTZZ6+IQMVa6S0Z
JSJ61H+cDK38bUBHQ5tk0TgGWLdAFfbuCP1Jje+NSCRUCMF5CFWviIlyFNuiQ8nPzuw4AZEiHV/6LygBZgvMjIRUweScIzfZkFD
KH2tAeG3Pcx8zkhJ4DqiWmJ1pnSk4AR0tGaJ0LtoFnNNCX3JlHkpKAEdrVpFFg/BPGikNCJyX7XGG0yZF88J6N7KCpg/z2pur57
ksild4akB3R+spyL1GOarjTQfoUHVOjlhKle4bkAiwTN43MOkL00p88EpmCPFec/9v+RtAMdMwbwbp+06Vl5k5EyEIqp5YtpUrn
EcQh3eUUbKuoXrtM1IWcHgzVGx2qgaJ14ZyTU5G9DhymUUUFFEXmOknCD+r/i7EVPmY1bYuqiapz7bRdYGdHjLelyrd/FynZF8A
1uKk8K7VOvEmF1nzICOVO2mgB77T+a/SMuJP+Y28xLQfcHjxHwTe15qJN/AnHzB4wguqScpJUW6AekL1QoTzrjzYBYCLqg3ZKkG
1T7+2khp0mZ6cPtysqyr8C8zkiOIsw7NlpsyJxjQUS7hJj4csxPIoKDV6iiGdE5Po9nc9wJAk2GeWXyKTz/6aaQMPP8WJLGk08k
cxthy6ebp2DEncxvPCej+qs3EahJfzNo8jC3kflYdjd8wkiMFJKCu5DIH37CkQ27NbTwlIAPBkMzxeLaTgtQ/UIIOqrb4SyO5wl
MCkqCuHMc0RkVS7dXcxnUDOhLaicAOmDINBm5IZq09qnHyo5E84SUBTP7f1eNysYf9GsvaJnVy6ruRPeNqBnQkuBfJPzClvd8J/
KRcwLD1GKlg8iaAZdq73mVKe+UzEFr8MLfJ38CdrftZGPufXPkn/Fjt45ZYNPnSB/LPgCQ6kw+RabYS1fi3azyp+4RjA8n4icqw
8mGkUMvtL96n3vgF0W/iaRpXqhpMFQAAAABJRU5ErkJggg==
""")

def main(config):
    station = json.decode(config.get("station_id", DEFAULT_STATION))

    allStatuses = fetch_cached(STATUS_URL, 240)["data"]["stations"]

    if len(allStatuses) > 0:
        stationStatus = [status for status in allStatuses if status["station_id"] == station["value"]]
        if len(stationStatus) > 0:
            stationStatus = stationStatus[0]

            # Extract counts for mechanical bikes and e-bikes from the num_bikes_available_types field
            mechanical_bikes = stationStatus["num_bikes_available_types"]["mechanical"]
            ebikes = stationStatus["num_bikes_available_types"]["ebike"]
            total_bikes = mechanical_bikes + ebikes
    else:
        # Handle the case when no station status is available
        fail("No station status available.")

    return render.Root(
        child = render.Column(
            cross_align = "end",
            children = [
                render.Column(
                    children = [
                        render.Marquee(
                            width = 64,
                            child = render.Text(station["display"]),
                        ),
                        render.Box(width = 64, height = 1, color = "#FFF"),
                    ],
                ),
                render.Row(
                    main_align = "space_around",
                    cross_align = "center",
                    expanded = True,
                    children = [
                        render.Image(src = IMAGE_BICYCLE, width = 40, height = 22),
                        render.Column(
                            main_align = "space_evenly",
                            cross_align = "end",
                            expanded = True,
                            children = [
                                render.Text("%d" % mechanical_bikes),
                                render.Row(
                                    children = [
                                        render.Image(src = IMAGE_LIGHTNING, width = 8, height = 8),
                                        render.Text("%d" % ebikes),
                                    ],
                                ),
                            ],
                        ),
                    ],
                ),
            ],
        ),
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.LocationBased(
                id = "station_id",
                name = "Toronto Bike Share station list",
                desc = "A list of bike share stations based on a location.",
                icon = "bicycle",
                handler = get_stations,
            ),
        ],
    )

def get_stations(location):
    loc = json.decode(location)

    result = fetch_cached(STATIONS_URL, 86400)
    if "data" not in result:
        fail("No data field found in result: %s" % str(result)[:100])
    if "stations" not in result["data"]:
        fail("No stations field found in data: %s" % str(result["data"])[:100])
    stations = result["data"]["stations"]

    return [
        schema.Option(
            display = station["name"],
            value = station["station_id"],
        )
        for station in sorted(stations, key = lambda station: square_distance(loc["lat"], loc["lng"], station["lat"], station["lon"]))
    ]

def square_distance(lat1, lon1, lat2, lon2):
    latitude_difference = int((float(lat2) - float(lat1)) * 10000)
    longitude_difference = int((float(lon2) - float(lon1)) * 10000)
    return latitude_difference * latitude_difference + longitude_difference * longitude_difference

def fetch_cached(url, ttl):
    cached = cache.get(url)
    if cached != None:
        return json.decode(cached)
    else:
        res = http.get(url)
        if res.status_code != 200:
            fail("GBFS request to %s failed with status %d", (url, res.status_code))
        data = res.json()

        # TODO: Determine if this cache call can be converted to the new HTTP cache.??
        cache.set(url, json.encode(data), ttl_seconds = ttl)
        return data
