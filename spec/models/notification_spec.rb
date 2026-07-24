require 'rails_helper'

RSpec.describe Notification, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:recipient).class_name('User') }
    it { is_expected.to belong_to(:notifiable) }
  end

  describe 'scopes' do
    let(:alice) { create(:user) }
    let(:bob) { create(:user) }

    describe '.unread' do
      it 'returns notifications where read_at is nil' do
        session = create(:game_session)
        participant = create(:game_session_participant, game_session: session, user: alice)
        unread = create(:notification, recipient: alice, notifiable: participant)
        create(:notification, recipient: alice, notifiable: participant, read_at: Time.current)

        expect(described_class.unread).to contain_exactly(unread)
      end
    end

    describe '.for_user' do
      it 'returns notifications for the given user' do
        session = create(:game_session)
        participant_a = create(:game_session_participant, game_session: session, user: alice)
        participant_b = create(:game_session_participant, game_session: session, user: bob)
        alice_notification = create(:notification, recipient: alice, notifiable: participant_a)
        create(:notification, recipient: bob, notifiable: participant_b)

        expect(described_class.for_user(alice)).to contain_exactly(alice_notification)
      end
    end
  end

  describe '#mark_as_read!' do
    it 'sets read_at to the current time' do
      session = create(:game_session)
      participant = create(:game_session_participant, game_session: session, user: create(:user))
      notification = create(:notification, recipient: participant.user, notifiable: participant)

      freeze_time do
        notification.mark_as_read!
        expect(notification.reload.read_at).to eq(Time.current)
      end
    end

    it 'does not affect other notifications' do
      session = create(:game_session)
      user = create(:user)
      participant = create(:game_session_participant, game_session: session, user: user)
      notification1 = create(:notification, recipient: user, notifiable: participant)
      notification2 = create(:notification, recipient: user, notifiable: participant)

      notification1.mark_as_read!
      expect(notification2.reload.read_at).to be_nil
    end
  end
end
