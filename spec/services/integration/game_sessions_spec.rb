require 'rails_helper'

RSpec.describe 'GameSessions lifecycle', type: :service do
  let(:logger) { create(:user) }
  let(:friend) { create(:user) }
  let(:game) { create(:game) }

  before do
    create(:friendship, :accepted, requester: logger, addressee: friend)
  end

  describe 'create → confirm → edit → re-confirm' do
    it 'completes the full lifecycle' do
      # Step 1: Create session
      create_result = GameSessions::Create.call(
        creator: logger,
        game_id: game.id,
        creator_score: 10,
        players: [
          { type: 'friend', user_id: friend.id, score: 20 }
        ]
      )
      expect(create_result.status).to eq(:created)
      game_session = create_result.game_session

      # Friend has a pending participation + notification
      friend_participant = game_session.game_session_participants.find_by(user: friend)
      expect(friend_participant).to be_pending
      expect(Notification.unread.for_user(friend).count).to eq(1)

      # Step 2: Friend confirms
      friend_participant.confirm!
      expect(friend_participant.reload).to be_confirmed
      expect(GameSession.visible_to(friend)).to include(game_session)

      # Step 3: Logger edits score
      update_result = GameSessions::Update.call(
        game_session: game_session,
        game_id: game.id,
        creator_score: 10,
        players: [
          { id: friend_participant.id, type: 'friend', user_id: friend.id, score: 50 }
        ]
      )
      expect(update_result.status).to eq(:updated)

      # Friend is reset to pending
      expect(friend_participant.reload).to be_pending
      expect(friend_participant.score).to eq(50)

      # Step 4: Friend re-confirms
      friend_participant.confirm!
      expect(friend_participant.reload).to be_confirmed
      expect(GameSession.visible_to(friend)).to include(game_session)
    end
  end

  describe 'privacy boundary' do
    it 'excludes session from rejected participant visibility' do
      create_result = GameSessions::Create.call(
        creator: logger,
        game_id: game.id,
        creator_score: 10,
        players: [
          { type: 'friend', user_id: friend.id, score: 20 }
        ]
      )
      game_session = create_result.game_session

      friend_participant = game_session.game_session_participants.find_by(user: friend)
      friend_participant.reject!

      expect(GameSession.visible_to(friend)).not_to include(game_session)
    end

    it 'always shows the session to the logger' do
      create_result = GameSessions::Create.call(
        creator: logger,
        game_id: game.id,
        creator_score: 10,
        players: [
          { type: 'friend', user_id: friend.id, score: 20 }
        ]
      )

      expect(GameSession.visible_to(logger)).to include(create_result.game_session)
    end
  end

  describe 'friendship validation' do
    it 'rejects tagging a non-friend' do
      stranger = create(:user)

      result = GameSessions::Create.call(
        creator: logger,
        game_id: game.id,
        creator_score: 10,
        players: [
          { type: 'friend', user_id: stranger.id, score: 20 }
        ]
      )

      expect(result.status).to eq(:not_friends)
      expect(GameSession.count).to eq(0)
    end
  end

  describe 'solo session' do
    it 'allows creating a session with only the logger' do
      result = GameSessions::Create.call(
        creator: logger,
        game_id: game.id,
        creator_score: 100,
        players: []
      )

      expect(result.status).to eq(:created)
      expect(result.game_session.game_session_participants.count).to eq(1)
      expect(GameSession.visible_to(logger)).to include(result.game_session)
    end
  end
end
