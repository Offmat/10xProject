require 'rails_helper'

RSpec.describe Game, type: :model do
  subject { build(:game) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:wikidata_id) }
    it { is_expected.to validate_uniqueness_of(:wikidata_id).ignoring_case_sensitivity }
    it { is_expected.to validate_presence_of(:source) }
    it { is_expected.to validate_numericality_of(:min_players).only_integer.is_greater_than(0).allow_nil }
    it { is_expected.to validate_numericality_of(:max_players).only_integer.is_greater_than(0).allow_nil }
    it { is_expected.to validate_numericality_of(:year_published).only_integer.allow_nil }
    it { is_expected.to validate_numericality_of(:play_time_minutes).only_integer.is_greater_than(0).allow_nil }
  end

  describe 'wikidata_id normalization' do
    it 'strips and upcases wikidata_id before save' do
      game = create(:game, wikidata_id: '  q123  ')

      expect(game.wikidata_id).to eq('Q123')
    end
  end

  describe 'player count consistency' do
    it 'is valid when max_players equals min_players' do
      game = build(:game, min_players: 2, max_players: 2)

      expect(game).to be_valid
    end

    it 'is valid when max_players is greater than min_players' do
      game = build(:game, min_players: 1, max_players: 4)

      expect(game).to be_valid
    end

    it 'is invalid when max_players is less than min_players' do
      game = build(:game, min_players: 4, max_players: 2)

      expect(game).not_to be_valid
      expect(game.errors[:max_players]).to include('must be greater than or equal to min_players')
    end

    it 'skips consistency check when min_players is nil' do
      game = build(:game, min_players: nil, max_players: 4)

      expect(game).to be_valid
    end

    it 'skips consistency check when max_players is nil' do
      game = build(:game, min_players: 2, max_players: nil)

      expect(game).to be_valid
    end
  end
end
