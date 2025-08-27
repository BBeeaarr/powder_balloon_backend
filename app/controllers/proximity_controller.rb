require "net/http"
require "json"
require "nokogiri"
require "open-uri"


class ProximityController < ApplicationController
  STATIC_POINT = [ -160.2, 23.5, 0.0 ] # [lon, lat, alt]
  EARTH_RADIUS_KM = 6371.0

  def closest_to_buoy
    station_id = params[:station] || "51101"
    buoy_coords = fetch_buoy_coordinates(station_id)

    return render json: { error: "Buoy coordinates not found" }, status: 404 unless buoy_coords

    balloon_coords = fetch_balloon_data
    return render json: { error: "Balloon data not found" }, status: 502 unless balloon_coords

    buoy_xyz = spherical_to_cartesian(*buoy_coords)

    closest = nil
    closest_index = nil
    min_distance = Float::INFINITY

    balloon_coords.each_with_index do |triplet, i|
      next unless triplet.is_a?(Array) && triplet.size == 3

      balloon_xyz = spherical_to_cartesian(*triplet)
      dist = euclidean_distance(buoy_xyz, balloon_xyz)
      if dist < min_distance
        min_distance = dist
        closest = triplet
        closest_index = i
      end
    end

    render json: {
      station: station_id,
      buoy_latitude: buoy_coords[0],
      buoy_longitude: buoy_coords[1],
      buoy_altitude_km: buoy_coords[2],
      closest_balloon_index: closest_index,
      closest_balloon_triplet: {
        longitude_deg: closest[0],
        latitude_deg: closest[1],
        altitude_km: closest[2]
      },
      distance_km: min_distance
    }
  end

  private

  def fetch_buoy_coordinates(station_id)
    url = "https://www.ndbc.noaa.gov/station_page.php?station=#{station_id}"
    html = URI.open(url)
    doc = Nokogiri::HTML(html)

    metadata = doc.at_css("#stn_metadata")
    line = metadata.css("b").find { |b| b.text.match?(/\d+\.\d+\s+[NS]\s+\d+\.\d+\s+[EW]/) }

    return nil unless line && line.text =~ /
      (?<lat_deg>[\d.]+)\s+(?<lat_dir>[NS])\s+
      (?<lon_deg>[\d.]+)\s+(?<lon_dir>[EW])
    /x

    match = Regexp.last_match
    lat = match[:lat_deg].to_f * (match[:lat_dir] == "S" ? -1 : 1)
    lon = match[:lon_deg].to_f * (match[:lon_dir] == "W" ? -1 : 1)
    alt = 0.0  # Assume sea level unless otherwise stated

    [ lat, lon, alt ]
  rescue
    nil
  end

  def fetch_balloon_data
    uri = URI("https://a.windbornesystems.com/treasure/00.json")
    response = Net::HTTP.get_response(uri)
    return nil unless response.is_a?(Net::HTTPSuccess)

    json = JSON.parse(response.body)
    json.is_a?(Array) ? json : json["data"]
  rescue
    nil
  end

  def spherical_to_cartesian(lon_deg, lat_deg, alt_km)
    r = EARTH_RADIUS_KM + alt_km
    lat_rad = lat_deg * Math::PI / 180
    lon_rad = lon_deg * Math::PI / 180

    x = r * Math.cos(lat_rad) * Math.cos(lon_rad)
    y = r * Math.cos(lat_rad) * Math.sin(lon_rad)
    z = r * Math.sin(lat_rad)

    [ x, y, z ]
  end

  def euclidean_distance(a, b)
    Math.sqrt((a[0] - b[0])**2 + (a[1] - b[1])**2 + (a[2] - b[2])**2)
  end
end
