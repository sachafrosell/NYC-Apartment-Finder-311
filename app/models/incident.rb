class Incident < ApplicationRecord

  belongs_to :complaint
  belongs_to :agency
  belongs_to :neighborhood

  # scopes for easy querying!
  scope :by_zips, -> (zips) { where(zip: zips) }
  scope :by_neighborhood, -> (neighborhood) { where(neighborhood: neighborhood) }
  scope :bad_sanitation, -> { joins(:complaint).where(complaints: { name: ["Rodent", "Unsanitary Pigeon Condition", "Overflowing Litter Baskets", "Sewer", "UNSANITARY CONDITION"] } ) }
  scope :noise_pollution, -> { joins(:complaint).where("complaints.name LIKE ?", "%Noise%") }
  scope :food_safety, -> { left_outer_joins(:complaint).where("complaints.name = ?", "Food Poisoning") }
  scope :death_sentence, -> { joins(:complaint).where(complaints: { name: ["Lead", "Radioactive Material", "Asbestos", "Hazardous Materials", "Industrial Waste", "Mold"] } ) }
  scope :bad_neighbors, -> { joins(:complaint).where(complaints: { name: ["Blocked Driveway", "Illegal Parking", "Noise", "Animal Abuse", "Drug Activity", "Illegal Fireworks", "Harboring Bees/Wasps"] } ) }
  scope :hip_neighborhood, -> { joins(:complaint).where(complaints: { name: ["Graffiti", "Smoking", "Drug Activity", "Illegal Animal Kept as Pet", "Bike/Roller/Skate Chronic", "Beach/Pool/Sauna Complaint", "Tattooing"] } ) }
  scope :air_quality, -> { joins(:complaint).where(complaints: { name: ["Smoking"] } ) }
  scope :neighborhood_aesthetics, -> { joins(:complaint).where(complaints: { name: ["PAINT/PLASTER", "Street Light Condition"] } ) }
  scope :utility_quality, -> { joins(:complaint).where(complaints: { name: ["HEAT/HOT WATER", "General Construction/Plumbing", "Sewer", "WATER LEAK", "Water System", "ELECTRIC"] } ) }

  # match criteria names (for dropdowns) to scope function names
  def self.criteria_hash
    {
      "Noise Levels": {
        "method" => :noise_pollution,
        "show_alias" => "Noise Complaints"
      },
      "Sanitary Conditions": {
        "method" => :bad_sanitation,
        "show_alias" => "Sanitation Complaints"
      },
      "Food Safety": {
        "method" => :food_safety,
        "show_alias" => "Food Poisoning Counts"
      },
      "Safe Environment": {
        "method" => :death_sentence,
        "show_alias" => "Hazardous Materials Found"
      },
      "Good Neighbors": {
        "method" => :bad_neighbors,
        "show_alias" => "Antisocial Behavior Complaints"
      },
      "Neighborhood Aesthetics": {
        "method" => :neighborhood_aesthetics,
        "show_alias" => "Aesthetic Maintenance Complaints"
      },
      "Air Quality": {
        "method" => :air_quality,
        "show_alias" => "Air Quality Complaints"
      },
      "Utility Quality": {
        "method" => :utility_quality,
        "show_alias" => "Utility Complaints"
      }
    }
  end

  def self.first_incident_date
    self.first.date_opened.strftime("%B %e, %Y at %I:%M%p")
  end

  def self.last_incident_date
    self.last.date_opened.strftime("%B %e, %Y at %I:%M%p")
  end

  def date_opened_string
    self.date_opened.strftime("%m/%-d/%y at %I:%M%p")
  end

  # returns an array of city names as strings
  def self.get_cities_from_zips(zips)
    self.by_zips(zips).select(:city).order(:city).distinct.map(&:city)
  end

  def self.get_zips_from_neighborhoods(name)
    self.joins(:neighborhood).select(:zip).where("neighborhoods.name = ?", name).distinct.map(&:zip)
    #returns array of unique zips
  end

  # returns an array of city names as strings
  def self.get_unique_zips
    zips = self.select(:zip).order(:zip).distinct.map(&:zip)
    parsed_zips = zips.select do |zip|
      zip && zip != "N/A" && zip != "0"
    end
    parsed_zips.sample(10) # this should be everything... limited to 10 for testing
  end

  def self.get_cities_from_valid_zips(address, minutes)
    old_zips = self.get_unique_zips
    new_zips = GoogleApi::Communicator.validate_zip(address, minutes, old_zips)
    self.get_cities_from_zips(new_zips)
  end

  # takes CSV row, parses data and saves to new Incident
  def self.create_from_csv_row(row, date_format)
    # neighborhood relationship depends on latlng - so only create incidents if this exists
    lonlat = row["Longitude"] && row["Latitude"] ? "POINT(#{row["Longitude"]} #{row["Latitude"]})" : nil
    if lonlat
      neighborhood = Neighborhood.find_by_lonlat(row["Longitude"], row["Latitude"]).first
      agency = Agency.find_or_create_by(name: row["Agency Name"])
      complaint = Complaint.find_or_create_by(name: row["Complaint Type"])
      date_opened_parsed = row["Created Date"] ? DateTime.strptime(row["Created Date"], date_format) : nil
      date_closed_parsed = row["Closed Date"] ? DateTime.strptime(row["Closed Date"], date_format) : nil
      parsed_zip = row["Incident Zip"] && row["Incident Zip"].length > 5 ? row["Incident Zip"][0..4] : row["Incident Zip"]
      incident_hash = {
        agency: agency,
        neighborhood: neighborhood,
        complaint: complaint,
        date_opened: date_opened_parsed,
        date_closed: date_closed_parsed,
        descriptor: row["Descriptor"],
        latitude: row["Latitude"] ? row["Latitude"].to_f : nil,
        longitude: row["Longitude"] ? row["Longitude"].to_f : nil,
        lonlat: lonlat,
        status: row["Status"] == "Open",
        zip: parsed_zip,
        incident_address: row["Incident Address"],
        city: row["City"] ? row["City"].upcase : nil
      }
      self.create(incident_hash)
    end
  end

  # takes API data as Hashie, parses data and saves to new Incident

  def self.create_from_api(api_hash, date_format)
    lonlat = api_hash.latitude && api_hash.longitude ? "POINT(#{api_hash.longitude} #{api_hash.latitude})" : nil
    if lonlat
      neighborhood = Neighborhood.find_by_lonlat(api_hash.longitude, api_hash.latitude).first
      agency = Agency.find_or_create_by(name: api_hash.agency_name)
      complaint = Complaint.find_or_create_by(name: api_hash.complaint_type)
      date_opened_parsed = api_hash.created_date ? DateTime.strptime(api_hash.created_date, date_format) : nil
      date_closed_parsed = api_hash.closed_date ? DateTime.strptime(api_hash.closed_date, date_format) : nil
      parsed_zip = api_hash.incident_zip && api_hash.incident_zip.length > 5 ? api_hash.incident_zip[0..4] : api_hash.incident_zip

      incident_hash = {
        agency: agency,
        neighborhood: neighborhood,
        complaint: complaint,
        date_opened: date_opened_parsed,
        date_closed: date_closed_parsed,
        descriptor: api_hash.descriptor,
        latitude: api_hash.latitude ? api_hash.latitude.to_f : nil,
        longitude: api_hash.longitude ? api_hash.longitude.to_f : nil,
        lonlat: lonlat,
        status: api_hash.status == "Open",
        zip: parsed_zip,
        incident_address: api_hash.incident_address,
        city: api_hash.city ? api_hash.city.upcase : nil
      }
      self.create(incident_hash)
    end
  end
end #end of Incident class
