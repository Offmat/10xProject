require 'rails_helper'

RSpec.describe Friendships::CreateRequest, type: :service do
  describe '.call' do
    let(:requester) { create(:user, email: 'requester@example.com') }
    let(:addressee) { create(:user, email: 'addressee@example.com') }

    def call(addressee_email = addressee.email)
      described_class.call(requester: requester, addressee_email: addressee_email)
    end

    it 'returns :not_found when no user matches the email' do
      result = call('missing@example.com')

      expect(result.status).to eq(:not_found)
      expect(result.friendship).to be_nil
      expect(Friendship.count).to eq(0)
    end

    it 'returns :self_request when the email is the requester' do
      result = call(requester.email)

      expect(result.status).to eq(:self_request)
      expect(Friendship.count).to eq(0)
    end

    it 'returns :requested and creates a pending row for a new request' do
      result = call

      expect(result.status).to eq(:requested)
      expect(result.friendship).to be_pending
      expect(result.friendship.requester).to eq(requester)
      expect(result.friendship.addressee).to eq(addressee)
      expect(Friendship.count).to eq(1)
    end

    it 'normalizes email before lookup' do
      result = call("  #{addressee.email.upcase}  ")

      expect(result.status).to eq(:requested)
    end

    it 'returns :already_requested when a pending row already exists in this direction' do
      existing = create(:friendship, requester: requester, addressee: addressee)

      result = call

      expect(result.status).to eq(:already_requested)
      expect(result.friendship).to eq(existing)
      expect(Friendship.count).to eq(1)
    end

    it 'returns :auto_accepted when a pending reverse request exists' do
      reverse = create(:friendship, requester: addressee, addressee: requester)

      result = call

      expect(result.status).to eq(:auto_accepted)
      expect(reverse.reload).to be_accepted
      expect(Friendship.count).to eq(1)
    end

    it 'reuses a declined row in this direction instead of inserting' do
      declined = create(:friendship, :declined, requester: requester, addressee: addressee)

      result = call

      expect(result.status).to eq(:requested)
      expect(declined.reload).to be_pending
      expect(Friendship.count).to eq(1)
    end

    it 'returns :already_friends when an accepted row exists in either direction' do
      create(:friendship, :accepted, requester: addressee, addressee: requester)

      result = call

      expect(result.status).to eq(:already_friends)
      expect(Friendship.count).to eq(1)
    end
  end
end
