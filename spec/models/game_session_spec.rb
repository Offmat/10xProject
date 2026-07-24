require 'rails_helper'

RSpec.describe GameSession, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:creator).class_name('User') }
    it { is_expected.to belong_to(:game) }
    it { is_expected.to have_many(:game_session_participants).dependent(:destroy) }
  end

  describe 'validations' do
    it 'is valid with all required attributes' do
      game_session = build(:game_session)
      expect(game_session).to be_valid
    end
  end

  describe 'scopes' do
    let(:alice) { create(:user) }
    let(:bob) { create(:user) }
    let(:game) { create(:game) }

    describe '.created_by' do
      it 'returns sessions created by the given user' do
        alice_session = create(:game_session, creator: alice, game: game)
        create(:game_session, creator: bob, game: game)

        expect(described_class.created_by(alice)).to contain_exactly(alice_session)
      end
    end

    describe '.visible_to' do
      let!(:alice_session) { create(:game_session, creator: alice, game: game) }
      let!(:bob_session) { create(:game_session, creator: bob, game: game) }

      it 'includes sessions created by the user' do
        expect(described_class.visible_to(alice)).to include(alice_session)
      end

      it 'includes sessions where user is a confirmed participant' do
        create(:game_session_participant, :confirmed, game_session: bob_session, user: alice)

        expect(described_class.visible_to(alice)).to include(bob_session)
      end

      it 'excludes sessions where user is a pending participant' do
        create(:game_session_participant, game_session: bob_session, user: alice, status: :pending)

        expect(described_class.visible_to(alice)).not_to include(bob_session)
      end

      it 'excludes sessions where user is a rejected participant' do
        create(:game_session_participant, :rejected, game_session: bob_session, user: alice)

        expect(described_class.visible_to(alice)).not_to include(bob_session)
      end
    end
  end
end
