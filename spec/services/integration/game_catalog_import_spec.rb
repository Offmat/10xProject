require 'rails_helper'

RSpec.describe 'Game catalog import', type: :service do
  include WikidataFixtures

  let(:seed_file) { Rails.root.join('spec/fixtures/wikidata/test_seed_list.yml') }
  let(:sparql_pattern) { %r{https://query\.wikidata\.org/sparql} }

  before do
    stub_request(:get, sparql_pattern)
      .to_return(status: 200, body: wikidata_fixture('sparql_response'),
                 headers: { 'Content-Type' => 'application/sparql-results+json' })
  end

  it 'creates games on first import with correct attributes' do
    result = GameCatalog::ImportService.call(seed_file:)

    expect(result).to include(created: 2, updated: 0, skipped: 0)
    expect(Game.count).to eq(2)

    terraforming_mars = Game.find_by(wikidata_id: 'Q36718832')
    expect(terraforming_mars).to have_attributes(
      name: 'Terraforming Mars',
      description: '2016 board game',
      bgg_id: '167791',
      min_players: 1,
      max_players: 5,
      year_published: 2016,
      play_time_minutes: 120,
      source: 'wikidata'
    )
    expect(terraforming_mars.imported_at).to be_present

    catan = Game.find_by(wikidata_id: 'Q17271')
    expect(catan).to have_attributes(
      name: 'The Settlers of Catan',
      bgg_id: '13',
      min_players: 3,
      max_players: 4,
      year_published: 1995,
      play_time_minutes: nil
    )
  end

  it 'updates existing games without creating duplicates on re-import' do
    GameCatalog::ImportService.call(seed_file:)
    first_count = Game.count

    result = GameCatalog::ImportService.call(seed_file:)

    expect(Game.count).to eq(first_count)
    expect(result).to include(created: 0, updated: 2, skipped: 0)
    expect(Game.pluck(:wikidata_id)).to match_array(%w[Q36718832 Q17271])
  end
end
