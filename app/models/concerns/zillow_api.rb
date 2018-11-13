module ZillowApi
  APP = Rails.application.credentials.zillow[:api_key]

  class ListingClient
    API_URL = "http://www.zillow.com"

    def get_listings(neighborhood, zip)
      request(
        http_method: :get,
        endpoint: "/webservice/GetSearchResults.htm",
        params: {
          "zws-id": APP,
          address: neighborhood,
          citystatezip: zip
        }
      )

    end

    private

    def client
      Faraday.new(API_URL) do |client|
        client.request :url_encoded
        client.adapter Faraday.default_adapter
      end
    end

    def request(http_method:, endpoint:, params: {})
      response = client.public_send(http_method, endpoint, params)
      doc = Nokogiri::XML(response.body)
      Hash.from_xml(doc.to_s)
    end

  end # end of ListingClient class



end