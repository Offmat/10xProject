require 'rails_helper'

RSpec.describe GameSessions::Create, type: :service do
  let(:creator) { create(:user) }
  let(:game) { create(:game) }

  describe '.call' do
    context 'when creating a solo session (logger only)' do
      it 'returns :created with the game session' do
        result = described_class.call(
          creator: creator,
          game_id: game.id,
          creator_score: 42,
          players: []
        )

        expect(result.status).to eq(:created)
        expect(result.game_session).to be_persisted
        expect(result.game_session.creator).to eq(creator)
        expect(result.game_session.game).to eq(game)
      end

      it 'creates a confirmed participant for the logger' do
        result = described_class.call(
          creator: creator,
          game_id: game.id,
          creator_score: 42,
          players: []
        )

        participant = result.game_session.game_session_participants.first
        expect(participant.user).to eq(creator)
        expect(participant.score).to eq(42)
        expect(participant).to be_confirmed
      end
    end

    context 'when creating with registered friends and guests' do
      let(:friend) { create(:user) }

      before do
        create(:friendship, :accepted, requester: creator, addressee: friend)
      end

      it 'creates participants for friends (pending) and guests (confirmed)' do
        result = described_class.call(
          creator: creator,
          game_id: game.id,
          creator_score: 10,
          players: [
            { type: 'friend', user_id: friend.id, score: 20 },
            { type: 'guest', guest_name: 'Bob', score: 30 }
          ]
        )

        expect(result.status).to eq(:created)
        participants = result.game_session.game_session_participants.order(:id)

        expect(participants.size).to eq(3)

        logger_p = participants.find_by(user: creator)
        expect(logger_p).to be_confirmed
        expect(logger_p.score).to eq(10)

        friend_p = participants.find_by(user: friend)
        expect(friend_p).to be_pending
        expect(friend_p.score).to eq(20)

        guest_p = participants.find_by(guest_name: 'Bob')
        expect(guest_p).to be_confirmed
        expect(guest_p.score).to eq(30)
      end

      it 'creates a notification for the registered friend' do
        result = described_class.call(
          creator: creator,
          game_id: game.id,
          creator_score: 10,
          players: [
            { type: 'friend', user_id: friend.id, score: 20 }
          ]
        )

        expect(Notification.count).to eq(1)
        notification = Notification.first
        expect(notification.recipient).to eq(friend)
        expect(notification.notifiable).to eq(
          result.game_session.game_session_participants.find_by(user: friend)
        )
      end

      it 'does not create notifications for guest players' do
        described_class.call(
          creator: creator,
          game_id: game.id,
          creator_score: 10,
          players: [
            { type: 'guest', guest_name: 'Bob', score: 30 }
          ]
        )

        expect(Notification.count).to eq(0)
      end
    end

    context 'when game is not found' do
      it 'returns :game_not_found' do
        result = described_class.call(
          creator: creator,
          game_id: -1,
          creator_score: 10,
          players: []
        )

        expect(result.status).to eq(:game_not_found)
        expect(result.game_session).to be_nil
      end
    end

    context 'when a tagged player is not a friend' do
      let(:stranger) { create(:user) }

      it 'returns :not_friends' do
        result = described_class.call(
          creator: creator,
          game_id: game.id,
          creator_score: 10,
          players: [
            { type: 'friend', user_id: stranger.id, score: 20 }
          ]
        )

        expect(result.status).to eq(:not_friends)
        expect(result.game_session).to be_nil
      end

      it 'does not create any records' do
        expect {
          described_class.call(
            creator: creator,
            game_id: game.id,
            creator_score: 10,
            players: [
              { type: 'friend', user_id: stranger.id, score: 20 }
            ]
          )
        }.not_to change(GameSession, :count)
      end
    end

    context 'when the creator is included in the players array' do
      it 'filters out the creator and does not create a duplicate participant' do
        result = described_class.call(
          creator: creator,
          game_id: game.id,
          creator_score: 42,
          players: [
            { type: 'friend', user_id: creator.id, score: 99 }
          ]
        )

        expect(result.status).to eq(:created)
        expect(result.game_session.game_session_participants.count).to eq(1)
      end
    end
  end
end
