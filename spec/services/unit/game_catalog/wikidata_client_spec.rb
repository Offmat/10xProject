require 'rails_helper'

RSpec.describe GameCatalog::WikidataClient, type: :service do
  include WikidataFixtures

  let(:sparql_pattern) { %r{https://query\.wikidata\.org/sparql} }

  describe '.fetch' do
    it 'returns parsed bindings from a successful SPARQL response' do
      stub_request(:get, sparql_pattern)
        .with(query: hash_including('format' => 'json'))
        .to_return(status: 200, body: wikidata_fixture('sparql_response'),
                   headers: { 'Content-Type' => 'application/sparql-results+json' })

      bindings = described_class.fetch(wikidata_ids: [ 'Q36718832' ])

      expect(bindings).to be_an(Array)
      expect(bindings.first.dig('game', 'value')).to include('Q36718832')
    end

    it 'sends a descriptive User-Agent header' do
      stub = stub_request(:get, sparql_pattern)
             .with(headers: { 'User-Agent' => /all-aBoard\/0\.1.*Ruby/ })
             .to_return(status: 200, body: wikidata_fixture('sparql_response'))

      described_class.fetch(wikidata_ids: [ 'Q36718832' ])

      expect(stub).to have_been_requested
    end

    it 'sends Accept header for SPARQL JSON results' do
      stub = stub_request(:get, sparql_pattern)
             .with(headers: { 'Accept' => 'application/sparql-results+json' })
             .to_return(status: 200, body: wikidata_fixture('sparql_response'))

      described_class.fetch(wikidata_ids: [ 'Q36718832' ])

      expect(stub).to have_been_requested
    end

    it 'builds a SPARQL query with VALUES clause from wikidata_ids' do
      stub = stub_request(:get, sparql_pattern)
             .with(query: hash_including('query' => /VALUES \?game \{ wd:Q36718832 wd:Q243519 \}/))
             .to_return(status: 200, body: wikidata_fixture('sparql_response'))

      described_class.fetch(wikidata_ids: %w[Q36718832 Q243519])

      expect(stub).to have_been_requested
    end

    it 'includes play time unit conversion in the SPARQL query' do
      stub = stub_request(:get, sparql_pattern)
             .with(query: hash_including('query' => /wikibase:quantityUnit.*Q11579/m))
             .to_return(status: 200, body: wikidata_fixture('sparql_response'))

      described_class.fetch(wikidata_ids: [ 'Q36718832' ])

      expect(stub).to have_been_requested
    end

    it 'retries once on timeout then succeeds' do
      stub_request(:get, sparql_pattern)
        .to_timeout
        .then
        .to_return(status: 200, body: wikidata_fixture('sparql_response'))

      bindings = described_class.fetch(wikidata_ids: [ 'Q36718832' ])

      expect(bindings).to be_an(Array)
      expect(WebMock).to have_requested(:get, sparql_pattern).twice
    end

    it 'retries once on 500 then succeeds' do
      stub_request(:get, sparql_pattern)
        .to_return(status: 500, body: 'Internal Server Error')
        .then
        .to_return(status: 200, body: wikidata_fixture('sparql_response'))

      bindings = described_class.fetch(wikidata_ids: [ 'Q36718832' ])

      expect(bindings).to be_an(Array)
      expect(WebMock).to have_requested(:get, sparql_pattern).twice
    end

    it 'raises after the second consecutive failure' do
      stub_request(:get, sparql_pattern).to_timeout

      expect do
        described_class.fetch(wikidata_ids: [ 'Q36718832' ])
      end.to raise_error(GameCatalog::WikidataClient::Error, 'Wikidata SPARQL request failed after retry')

      expect(WebMock).to have_requested(:get, sparql_pattern).twice
    end

    it 'raises immediately on 4xx responses without retrying' do
      stub_request(:get, sparql_pattern)
        .to_return(status: 429, body: 'Too Many Requests')

      expect do
        described_class.fetch(wikidata_ids: [ 'Q36718832' ])
      end.to raise_error(GameCatalog::WikidataClient::Error, /429/)

      expect(WebMock).to have_requested(:get, sparql_pattern).once
    end

    it 'returns empty array when no bindings in response' do
      stub_request(:get, sparql_pattern)
        .to_return(status: 200, body: { results: { bindings: [] } }.to_json)

      bindings = described_class.fetch(wikidata_ids: [ 'Q99999999' ])

      expect(bindings).to eq([])
    end
  end
end
