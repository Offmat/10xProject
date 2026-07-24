class GameSessionParticipant < ApplicationRecord
  belongs_to :game_session
  belongs_to :user, optional: true
  has_many :notifications, as: :notifiable, dependent: :destroy

  enum :status, { pending: 0, confirmed: 1, rejected: 2 }

  validates :score, presence: true, numericality: { only_integer: true }
  validates :user_id, uniqueness: { scope: :game_session_id }, allow_nil: true
  validate :exactly_one_identity

  def confirm!
    update!(status: :confirmed)
  end

  def reject!
    update!(status: :rejected)
  end

  def registered?
    user_id.present?
  end

  def guest?
    guest_name.present?
  end

  def display_name
    registered? ? user.email : guest_name
  end

  private

  def exactly_one_identity
    if user_id.present? && guest_name.present?
      errors.add(:base, 'cannot have both user and guest_name')
    elsif user_id.blank? && guest_name.blank?
      errors.add(:base, 'must have either user or guest_name')
    end
  end
end
