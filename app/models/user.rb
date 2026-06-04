class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_blank: true

  normalizes :email, with: ->(e) { e.strip.downcase }
end
