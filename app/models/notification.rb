class Notification < ApplicationRecord
  belongs_to :recipient, class_name: 'User'
  belongs_to :notifiable, polymorphic: true

  scope :unread, -> { where(read_at: nil) }
  scope :for_user, ->(user) { where(recipient: user) }

  def mark_as_read!
    update!(read_at: Time.current)
  end
end
