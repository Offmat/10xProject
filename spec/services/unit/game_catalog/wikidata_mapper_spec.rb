require 'rails_helper'

RSpec.describe GameCatalog::WikidataMapper, type: :service do
  include WikidataFixtures

  describe '.call' do
    let(:bindings) { parsed_wikidata_fixture('sparql_response').dig('results', 'bindings') }

    it 'extracts all fields from a rich SPARQL result' do
      attrs_list = described_class.call(bindings)
      terraforming = attrs_list.find { |a| a[:wikidata_id] == 'Q36718832' }

      expect(terraforming).to include(
        wikidata_id: 'Q36718832',
        name: 'Terraforming Mars',
        description: '2016 board game',
        bgg_id: '167791',
        min_players: 1,
        max_players: 5,
        year_published: 2016,
        play_time_minutes: 120,
        source: 'wikidata'
      )
    end

    it 'maps fields without play time (nil when absent)' do
      attrs_list = described_class.call(bindings)
      catan = attrs_list.find { |a| a[:wikidata_id] == 'Q17271' }

      expect(catan).to include(
        wikidata_id: 'Q17271',
        name: 'The Settlers of Catan',
        bgg_id: '13',
        min_players: 3,
        max_players: 4,
        year_published: 1995,
        play_time_minutes: nil
      )
    end

    it 'uses seed_names fallback when label is missing' do
      bindings = [
        { 'game' => { 'value' => 'http://www.wikidata.org/entity/Q999' } }
      ]

      attrs_list = described_class.call(bindings, seed_names: { 'Q999' => 'Mystery Game' })

      expect(attrs_list.first[:name]).to eq('Mystery Game')
    end

    it 'returns nil name when no label or seed_name exists' do
      bindings = [
        { 'game' => { 'value' => 'http://www.wikidata.org/entity/Q999' } }
      ]

      attrs_list = described_class.call(bindings)

      expect(attrs_list.first[:name]).to be_nil
    end

    it 'extracts year from ISO date string' do
      bindings = [
        {
          'game' => { 'value' => 'http://www.wikidata.org/entity/Q111' },
          'gameLabel' => { 'value' => 'Test' },
          'pubDate' => { 'value' => '2020-06-15T00:00:00Z' }
        }
      ]

      attrs_list = described_class.call(bindings)

      expect(attrs_list.first[:year_published]).to eq(2020)
    end

    it 'deduplicates multiple SPARQL rows for the same game' do
      bindings = [
        {
          'game' => { 'value' => 'http://www.wikidata.org/entity/Q111' },
          'gameLabel' => { 'value' => 'Dupe Game' },
          'bggId' => { 'value' => '100' }
        },
        {
          'game' => { 'value' => 'http://www.wikidata.org/entity/Q111' },
          'gameLabel' => { 'value' => 'Dupe Game' },
          'bggId' => { 'value' => '200' }
        }
      ]

      attrs_list = described_class.call(bindings)

      expect(attrs_list.size).to eq(1)
      expect(attrs_list.first[:wikidata_id]).to eq('Q111')
    end

    it 'handles an empty bindings array' do
      expect(described_class.call([])).to eq([])
    end
  end
end
