class BalloonsController < ApplicationController
  def closest
    buoy_lat = params[:lat].to_f
    buoy_lon = params[:lon].to_f
    balloons = params[:balloons] # array of { lat, lon, alt }

    closest_balloon = balloons.min_by do |b|
      haversine(buoy_lat, buoy_lon, b["lat"], b["lon"])
    end

    render json: { powder_balloon: closest_balloon }
  end

  private

  def haversine(lat1, lon1, lat2, lon2)
    rad_per_deg = Math::PI / 180
    r_km = 6371 # Earth radius in km
    dlat = (lat2 - lat1) * rad_per_deg
    dlon = (lon2 - lon1) * rad_per_deg

    a = Math.sin(dlat / 2)**2 +
        Math.cos(lat1 * rad_per_deg) * Math.cos(lat2 * rad_per_deg) *
        Math.sin(dlon / 2)**2

    c = 2 * Math::atan2(Math::sqrt(a), Math::sqrt(1 - a))
    r_km * c
  end
end
