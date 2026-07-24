class GameSession < ApplicationRecord
  belongs_to :creator, class_name: 'User'
  belongs_to :game
  has_many :game_session_participants, dependent: :destroy

  scope :created_by, ->(user) { where(creator: user) }
  scope :visible_to, ->(user) {
    where(creator: user).or(
      where(id: GameSessionParticipant.confirmed.where(user: user).select(:game_session_id))
    )
  }
end
