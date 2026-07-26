class Notification < ApplicationRecord
  REASONS = %w[invitation update update_after_rejection].freeze

  belongs_to :recipient, class_name: 'User'
  belongs_to :notifiable, polymorphic: true

  validates :reason, inclusion: { in: REASONS }

  scope :unread, -> { where(read_at: nil) }
  scope :for_user, ->(user) { where(recipient: user) }

  def mark_as_read!
    update!(read_at: Time.current)
  end
end
