class Game < ApplicationRecord
  has_many :game_sessions

  validates :name, presence: true
  validates :wikidata_id, presence: true, uniqueness: true
  validates :source, presence: true
  validates :min_players, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :max_players, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :year_published, numericality: { only_integer: true }, allow_nil: true
  validates :play_time_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  validate :player_count_consistency, if: -> { min_players.present? && max_players.present? }

  normalizes :wikidata_id, with: ->(id) { id.strip.upcase }

  private

  def player_count_consistency
    return if max_players >= min_players

    errors.add(:max_players, 'must be greater than or equal to min_players')
  end
end
