class Friendship < ApplicationRecord
  belongs_to :requester, class_name: 'User'
  belongs_to :addressee, class_name: 'User'

  enum :status, { pending: 0, accepted: 1, declined: 2 }

  validate :cannot_friend_self

  scope :incoming_to, ->(user) { pending.where(addressee: user) }
  scope :outgoing_from, ->(user) { pending.where(requester: user) }
  scope :involving, ->(user) { where(requester: user).or(where(addressee: user)) }
  scope :accepted_involving, ->(user) { accepted.involving(user) }

  def accept!
    update!(status: :accepted)
  end

  def decline!
    update!(status: :declined)
  end

  private

  def cannot_friend_self
    return unless requester_id.present? && requester_id == addressee_id

    errors.add(:base, 'cannot friend yourself')
  end
end
