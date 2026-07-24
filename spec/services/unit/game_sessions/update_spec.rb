require 'rails_helper'

RSpec.describe GameSessions::Update, type: :service do
  let(:creator) { create(:user) }
  let(:friend) { create(:user) }
  let(:game) { create(:game) }
  let(:game_session) { create(:game_session, creator: creator, game: game) }
  let!(:logger_participant) do
    create(:game_session_participant, :confirmed, game_session: game_session, user: creator, score: 10)
  end

  before do
    create(:friendship, :accepted, requester: creator, addressee: friend)
  end

  describe '.call' do
    context 'when updating logger score only' do
      it 'returns :updated and changes the score' do
        result = described_class.call(
          game_session: game_session,
          game_id: game.id,
          creator_score: 99,
          players: []
        )

        expect(result.status).to eq(:updated)
        expect(logger_participant.reload.score).to eq(99)
      end

      it 'does not create notifications for logger score change' do
        expect {
          described_class.call(
            game_session: game_session,
            game_id: game.id,
            creator_score: 99,
            players: []
          )
        }.not_to change(Notification, :count)
      end
    end

    context 'when a registered participant score changes' do
      let!(:friend_participant) do
        create(:game_session_participant, :confirmed, game_session: game_session, user: friend, score: 20)
      end
      let!(:old_notification) do
        create(:notification, recipient: friend, notifiable: friend_participant, read_at: Time.current)
      end

      it 'resets participant to pending and re-notifies' do
        result = described_class.call(
          game_session: game_session,
          game_id: game.id,
          creator_score: 10,
          players: [
            { id: friend_participant.id, type: 'friend', user_id: friend.id, score: 50 }
          ]
        )

        expect(result.status).to eq(:updated)
        expect(friend_participant.reload).to be_pending
        expect(friend_participant.score).to eq(50)
      end

      it 'destroys old notifications and creates a new one' do
        described_class.call(
          game_session: game_session,
          game_id: game.id,
          creator_score: 10,
          players: [
            { id: friend_participant.id, type: 'friend', user_id: friend.id, score: 50 }
          ]
        )

        expect(Notification.where(id: old_notification.id)).not_to exist
        expect(Notification.where(recipient: friend, notifiable: friend_participant).count).to eq(1)
      end
    end

    context 'when the game changes' do
      let(:new_game) { create(:game) }
      let!(:friend_participant) do
        create(:game_session_participant, :confirmed, game_session: game_session, user: friend, score: 20)
      end

      it 'resets all non-logger registered participants to pending' do
        described_class.call(
          game_session: game_session,
          game_id: new_game.id,
          creator_score: 10,
          players: [
            { id: friend_participant.id, type: 'friend', user_id: friend.id, score: 20 }
          ]
        )

        expect(friend_participant.reload).to be_pending
        expect(game_session.reload.game).to eq(new_game)
      end

      it 'creates fresh notifications for all registered participants' do
        described_class.call(
          game_session: game_session,
          game_id: new_game.id,
          creator_score: 10,
          players: [
            { id: friend_participant.id, type: 'friend', user_id: friend.id, score: 20 }
          ]
        )

        expect(Notification.where(recipient: friend).count).to eq(1)
      end
    end

    context 'when adding a new participant' do
      it 'creates a new registered participant with notification' do
        result = described_class.call(
          game_session: game_session,
          game_id: game.id,
          creator_score: 10,
          players: [
            { type: 'friend', user_id: friend.id, score: 30 }
          ]
        )

        expect(result.status).to eq(:updated)
        new_participant = game_session.game_session_participants.find_by(user: friend)
        expect(new_participant).to be_pending
        expect(new_participant.score).to eq(30)
        expect(Notification.where(recipient: friend).count).to eq(1)
      end

      it 'creates a new guest participant without notification' do
        result = described_class.call(
          game_session: game_session,
          game_id: game.id,
          creator_score: 10,
          players: [
            { type: 'guest', guest_name: 'Alice', score: 25 }
          ]
        )

        expect(result.status).to eq(:updated)
        guest = game_session.game_session_participants.find_by(guest_name: 'Alice')
        expect(guest).to be_confirmed
        expect(Notification.count).to eq(0)
      end
    end

    context 'when removing a participant' do
      let!(:friend_participant) do
        create(:game_session_participant, game_session: game_session, user: friend, score: 20)
      end
      let!(:notification) do
        create(:notification, recipient: friend, notifiable: friend_participant)
      end

      it 'destroys the participant and cascades to notifications' do
        described_class.call(
          game_session: game_session,
          game_id: game.id,
          creator_score: 10,
          players: []
        )

        expect(GameSessionParticipant.where(id: friend_participant.id)).not_to exist
        expect(Notification.where(id: notification.id)).not_to exist
      end
    end

    context 'when guest score changes' do
      let!(:guest_participant) do
        create(:game_session_participant, :guest, :confirmed, game_session: game_session, guest_name: 'Bob', score: 15)
      end

      it 'updates the score without creating notifications' do
        described_class.call(
          game_session: game_session,
          game_id: game.id,
          creator_score: 10,
          players: [
            { id: guest_participant.id, type: 'guest', guest_name: 'Bob', score: 50 }
          ]
        )

        expect(guest_participant.reload.score).to eq(50)
        expect(Notification.count).to eq(0)
      end
    end

    context 'when game is not found' do
      it 'returns :game_not_found' do
        result = described_class.call(
          game_session: game_session,
          game_id: -1,
          creator_score: 10,
          players: []
        )

        expect(result.status).to eq(:game_not_found)
      end
    end

    context 'when a new player is not a friend' do
      let(:stranger) { create(:user) }

      it 'returns :not_friends' do
        result = described_class.call(
          game_session: game_session,
          game_id: game.id,
          creator_score: 10,
          players: [
            { type: 'friend', user_id: stranger.id, score: 20 }
          ]
        )

        expect(result.status).to eq(:not_friends)
      end
    end
  end
end
