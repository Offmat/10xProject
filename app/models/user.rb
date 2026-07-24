class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :sent_friendships, class_name: 'Friendship', foreign_key: :requester_id, dependent: :destroy
  has_many :received_friendships, class_name: 'Friendship', foreign_key: :addressee_id, dependent: :destroy
  has_many :created_game_sessions, class_name: 'GameSession', foreign_key: :creator_id, dependent: :destroy
  has_many :game_session_participations, class_name: 'GameSessionParticipant'
  has_many :notifications, foreign_key: :recipient_id, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_blank: true

  normalizes :email, with: ->(e) { e.strip.downcase }

  def friends
    counterpart_ids = Friendship.accepted_involving(self).select(
      Arel.sql(
        Friendship.sanitize_sql_array([
          <<~SQL.squish,
            CASE
              WHEN requester_id = ? THEN addressee_id
              ELSE requester_id
            END
          SQL
          id
        ])
      )
    )
    User.where(id: counterpart_ids)
  end
end
