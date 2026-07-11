require 'rails_helper'

RSpec.describe GameCatalog::ImportService, type: :service do
  let(:seed_file) { Rails.root.join('spec/fixtures/wikidata/test_seed_list.yml') }
  let(:bindings) do
    [
      {
        'game' => { 'value' => 'http://www.wikidata.org/entity/Q36718832' },
        'gameLabel' => { 'value' => 'Terraforming Mars' },
        'gameDescription' => { 'value' => 'board game published in 2016' }
      },
      {
        'game' => { 'value' => 'http://www.wikidata.org/entity/Q17271' },
        'gameLabel' => { 'value' => 'Catan' }
      }
    ]
  end

  before do
    allow(GameCatalog::WikidataClient).to receive(:fetch).and_return(bindings)
  end

  describe '.call' do
    it 'reads the seed file and fetches entities by wikidata_id' do
      expect(GameCatalog::WikidataClient).to receive(:fetch)
        .with(wikidata_ids: %w[Q36718832 Q17271])
        .and_return(bindings)

      described_class.call(seed_file:)
    end

    it 'returns created, updated, skipped counts and warnings' do
      result = described_class.call(seed_file:)

      expect(result).to include(created: 2, updated: 0, skipped: 0, warnings: [])
    end

    it 'updates existing records on re-import' do
      described_class.call(seed_file:)

      result = described_class.call(seed_file:)

      expect(result).to include(created: 0, updated: 2, skipped: 0)
    end

    it 'skips entries missing from the API response and adds a warning' do
      allow(GameCatalog::WikidataClient).to receive(:fetch).and_return([])

      result = described_class.call(seed_file:)

      expect(result[:skipped]).to eq(2)
      expect(result[:warnings]).to include(
        'Entity Q36718832 not returned by Wikidata API',
        'Entity Q17271 not returned by Wikidata API'
      )
    end

    it 'skips invalid records and collects validation warnings' do
      allow(GameCatalog::WikidataMapper).to receive(:call).and_return([
        { wikidata_id: 'Q36718832', name: nil, description: nil, bgg_id: nil,
          min_players: nil, max_players: nil, year_published: nil,
          play_time_minutes: nil, source: 'wikidata' },
        { wikidata_id: 'Q17271', name: nil, description: nil, bgg_id: nil,
          min_players: nil, max_players: nil, year_published: nil,
          play_time_minutes: nil, source: 'wikidata' }
      ])

      result = described_class.call(seed_file:)

      expect(result[:skipped]).to eq(2)
      expect(result[:warnings].first).to match(/Skipped Q36718832/)
    end

    it 'passes seed_names to the mapper for label fallback' do
      expect(GameCatalog::WikidataMapper).to receive(:call)
        .with(bindings, seed_names: { 'Q36718832' => 'Terraforming Mars', 'Q17271' => 'Catan' })
        .and_call_original

      described_class.call(seed_file:)
    end
  end
end
