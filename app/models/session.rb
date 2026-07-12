class Session < ApplicationRecord
  LIFETIME = 30.days

  belongs_to :user

  scope :active, -> { where('created_at > ?', LIFETIME.ago) }

  def self.sweep
    deleted = where('created_at <= ?', LIFETIME.ago).delete_all
    deleted
  end
end
