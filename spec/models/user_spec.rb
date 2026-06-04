require 'rails_helper'

RSpec.describe User, type: :model do
  subject do
    described_class.new(
      email: 'player@example.com',
      password: 'password',
      password_confirmation: 'password'
    )
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to allow_value('player@example.com').for(:email) }
    it { is_expected.not_to allow_value('notanemail').for(:email) }
  end

  describe 'email normalization' do
    it 'strips and downcases email before save' do
      user = described_class.create!(
        email: '  Player@Example.COM  ',
        password: 'password',
        password_confirmation: 'password'
      )

      expect(user.email).to eq('player@example.com')
    end
  end

  describe 'password' do
    it 'authenticates with the correct password' do
      user = described_class.create!(
        email: 'player@example.com',
        password: 'secret12',
        password_confirmation: 'secret12'
      )

      expect(described_class.authenticate_by(email: 'player@example.com', password: 'secret12')).to eq(user)
      expect(described_class.authenticate_by(email: 'player@example.com', password: 'wrong')).to be_nil
    end
  end
end
