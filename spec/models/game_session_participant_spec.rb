require 'rails_helper'

RSpec.describe GameSessionParticipant, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:game_session) }
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to have_many(:notifications).dependent(:destroy) }
  end

  describe 'enum' do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, confirmed: 1, rejected: 2) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:score) }
    it { is_expected.to validate_numericality_of(:score).only_integer }

    context 'player identity' do
      it 'is valid with user_id and no guest_name' do
        user = create(:user)
        session = create(:game_session)
        participant = build(:game_session_participant, game_session: session, user: user)
        expect(participant).to be_valid
      end

      it 'is valid with guest_name and no user_id' do
        session = create(:game_session)
        participant = build(:game_session_participant, :guest, game_session: session)
        expect(participant).to be_valid
      end

      it 'is invalid with both user_id and guest_name' do
        user = create(:user)
        session = create(:game_session)
        participant = build(:game_session_participant, game_session: session, user: user, guest_name: 'Ghost')
        expect(participant).not_to be_valid
        expect(participant.errors[:base]).to include('cannot have both user and guest_name')
      end

      it 'is invalid with neither user_id nor guest_name' do
        session = create(:game_session)
        participant = build(:game_session_participant, game_session: session, user: nil, guest_name: nil)
        expect(participant).not_to be_valid
        expect(participant.errors[:base]).to include('must have either user or guest_name')
      end
    end

    context 'uniqueness' do
      it 'prevents the same user from participating twice in one session' do
        user = create(:user)
        session = create(:game_session)
        create(:game_session_participant, game_session: session, user: user)

        duplicate = build(:game_session_participant, game_session: session, user: user)
        expect(duplicate).not_to be_valid
      end

      it 'allows the same user in different sessions' do
        user = create(:user)
        session1 = create(:game_session)
        session2 = create(:game_session)
        create(:game_session_participant, game_session: session1, user: user)

        participant = build(:game_session_participant, game_session: session2, user: user)
        expect(participant).to be_valid
      end
    end
  end

  describe '#confirm! and #reject!' do
    let(:participant) { create(:game_session_participant) }

    it 'confirm! sets status to confirmed' do
      participant.confirm!
      expect(participant.reload).to be_confirmed
    end

    it 'reject! sets status to rejected' do
      participant.reject!
      expect(participant.reload).to be_rejected
    end
  end

  describe 'helper methods' do
    describe '#registered?' do
      it 'returns true when user_id is present' do
        user = create(:user)
        session = create(:game_session)
        participant = build(:game_session_participant, game_session: session, user: user)
        expect(participant).to be_registered
      end

      it 'returns false for guest participants' do
        session = create(:game_session)
        participant = build(:game_session_participant, :guest, game_session: session)
        expect(participant).not_to be_registered
      end
    end

    describe '#guest?' do
      it 'returns true when guest_name is present' do
        participant = build(:game_session_participant, :guest)
        expect(participant).to be_guest
      end

      it 'returns false for registered participants' do
        participant = build(:game_session_participant)
        expect(participant).not_to be_guest
      end
    end

    describe '#display_name' do
      it 'returns user email for registered participants' do
        user = create(:user, email: 'player@example.com')
        participant = build(:game_session_participant, user: user)

        expect(participant.display_name).to eq('player@example.com')
      end

      it 'returns guest_name for guest participants' do
        participant = build(:game_session_participant, :guest, guest_name: 'Bob')

        expect(participant.display_name).to eq('Bob')
      end
    end
  end
end
