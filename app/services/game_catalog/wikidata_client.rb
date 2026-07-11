require 'net/http'
require 'json'
require 'uri'

module GameCatalog
  class WikidataClient
    class Error < StandardError; end

    SPARQL_URL = 'https://query.wikidata.org/sparql'
    TIMEOUT_SECONDS = 30
    USER_AGENT = "all-aBoard/0.1 (contact) Ruby/#{RUBY_VERSION}".freeze

    QUERY_TEMPLATE = <<~SPARQL
      SELECT ?game ?gameLabel ?gameDescription
             ?bggId ?minPlayers ?maxPlayers ?pubDate ?playTime
      WHERE {
        VALUES ?game { %{qids} }
        OPTIONAL { ?game wdt:P2339 ?bggId. }
        OPTIONAL { ?game wdt:P1872 ?minPlayers. }
        OPTIONAL { ?game wdt:P1873 ?maxPlayers. }
        OPTIONAL { ?game wdt:P577  ?pubDate. }
        OPTIONAL {
          ?game p:P2047 ?_ptStmt.
          ?_ptStmt a wikibase:BestRank;
                   psv:P2047 ?_ptNode.
          ?_ptNode wikibase:quantityAmount ?_ptRaw;
                   wikibase:quantityUnit ?_ptUnit.
          BIND(IF(?_ptUnit = wd:Q11579, ?_ptRaw * 60, ?_ptRaw) AS ?playTime)
        }
        SERVICE wikibase:label {
          bd:serviceParam wikibase:language "en,mul".
        }
      }
    SPARQL

    def self.fetch(wikidata_ids:)
      new.fetch(wikidata_ids)
    end

    def fetch(wikidata_ids)
      qids = wikidata_ids.map { |id| "wd:#{id}" }.join(' ')
      query = format(QUERY_TEMPLATE, qids: qids)
      response = request_with_retry(query)
      parsed = JSON.parse(response.body)

      parsed.dig('results', 'bindings') || []
    end

    private

    def request_with_retry(query)
      attempt = 0

      begin
        attempt += 1
        perform_request(query)
      rescue Net::OpenTimeout, Net::ReadTimeout, TransientError
        raise Error, 'Wikidata SPARQL request failed after retry' if attempt > 1

        retry
      end
    end

    def perform_request(query)
      uri = URI(SPARQL_URL)
      uri.query = URI.encode_www_form(query: query, format: 'json')

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT_SECONDS,
                                                     read_timeout: TIMEOUT_SECONDS) do |http|
        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] = USER_AGENT
        request['Accept'] = 'application/sparql-results+json'
        http.request(request)
      end

      raise TransientError, "Wikidata SPARQL returned #{response.code}" if response.code.to_i >= 500
      raise Error, "Wikidata SPARQL returned #{response.code}" unless response.code.to_i < 400

      response
    end

    class TransientError < StandardError; end
  end
end
