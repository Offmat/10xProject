require 'rails_helper'

RSpec.describe Friendship, type: :model do
  describe 'enum' do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, accepted: 1, declined: 2) }
  end

  describe 'validations' do
    it 'rejects self-friend requests' do
      user = create(:user)
      friendship = build(:friendship, requester: user, addressee: user)

      expect(friendship).not_to be_valid
      expect(friendship.errors[:base]).to include('cannot friend yourself')
    end
  end

  describe 'scopes' do
    let(:alice) { create(:user, email: 'alice@example.com') }
    let(:bob) { create(:user, email: 'bob@example.com') }
    let(:carol) { create(:user, email: 'carol@example.com') }

    let!(:incoming_pending) { create(:friendship, requester: bob, addressee: alice) }
    let!(:outgoing_pending) { create(:friendship, requester: alice, addressee: carol) }
    let!(:accepted_friendship) { create(:friendship, :accepted, requester: alice, addressee: bob) }
    let!(:declined_friendship) { create(:friendship, :declined, requester: carol, addressee: alice) }

    describe '.incoming_to' do
      it 'returns pending requests where the user is the addressee' do
        expect(described_class.incoming_to(alice)).to contain_exactly(incoming_pending)
      end
    end

    describe '.outgoing_from' do
      it 'returns pending requests where the user is the requester' do
        expect(described_class.outgoing_from(alice)).to contain_exactly(outgoing_pending)
      end
    end

    describe '.involving' do
      it 'returns rows where the user is requester or addressee' do
        expect(described_class.involving(alice)).to contain_exactly(
          incoming_pending,
          outgoing_pending,
          accepted_friendship,
          declined_friendship
        )
      end
    end

    describe '.accepted_involving' do
      it 'returns accepted rows where the user is requester or addressee' do
        expect(described_class.accepted_involving(alice)).to contain_exactly(accepted_friendship)
      end
    end
  end

  describe '#accept! and #decline!' do
    let(:friendship) { create(:friendship) }

    it 'accept! sets status to accepted' do
      friendship.accept!

      expect(friendship.reload).to be_accepted
    end

    it 'decline! sets status to declined' do
      friendship.decline!

      expect(friendship.reload).to be_declined
    end
  end

  describe 'User#friends' do
    let(:alice) { create(:user, email: 'alice@example.com') }
    let(:bob) { create(:user, email: 'bob@example.com') }

    it 'returns the accepted counterpart user from either side of the relationship' do
      friendship = create(:friendship, requester: alice, addressee: bob)
      friendship.accept!

      expect(alice.friends).to contain_exactly(bob)
      expect(bob.friends).to contain_exactly(alice)
    end

    it 'excludes pending and declined relationships' do
      create(:friendship, requester: alice, addressee: bob)
      create(:friendship, :declined, requester: bob, addressee: alice)

      expect(alice.friends).to be_empty
      expect(bob.friends).to be_empty
    end
  end
end
