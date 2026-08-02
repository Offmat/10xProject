require 'rails_helper'

RSpec.describe 'GameSessions', type: :request do
  let(:alice) { create(:user, email: 'alice@example.com') }
  let(:bob) { create(:user, email: 'bob@example.com') }
  let(:carol) { create(:user, email: 'carol@example.com') }
  let(:game) { create(:game, name: 'Catan') }

  before do
    create(:friendship, :accepted, requester: alice, addressee: bob)
  end

  describe 'GET /game_sessions' do
    before { sign_in_as(alice) }

    it 'lists sessions visible to the current user' do
      session = create(:game_session, creator: alice, game: game)
      create(:game_session_participant, :confirmed, game_session: session, user: alice, score: 10)

      get game_sessions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Catan')
    end

    it 'does not list sessions the user cannot see' do
      other_user = create(:user)
      session = create(:game_session, creator: other_user, game: game)
      create(:game_session_participant, :confirmed, game_session: session, user: other_user, score: 5)

      get game_sessions_path

      expect(response.body).not_to include('Catan')
    end

    it 'does not list a session while the tagged friend is still pending' do
      pending_game = create(:game, name: 'Azul')
      session = create(:game_session, creator: bob, game: pending_game)
      create(:game_session_participant, :confirmed, game_session: session, user: bob, score: 10)
      create(:game_session_participant, game_session: session, user: alice, score: 8)

      get game_sessions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Azul')
    end

    it 'shows empty state when no sessions exist' do
      get game_sessions_path

      expect(response.body).to include('No sessions yet')
    end
  end

  describe 'GET /game_sessions/new' do
    before { sign_in_as(alice) }

    it 'renders the new session form' do
      get new_game_session_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Log a Session')
      expect(response.body).to include('Your score')
    end
  end

  describe 'POST /game_sessions' do
    before { sign_in_as(alice) }

    it 'creates a session and redirects with flash' do
      post game_sessions_path, params: {
        game_session: {
          game_id: game.id,
          creator_score: 42,
          players: {
            '0' => { type: 'friend', user_id: bob.id, score: 30 },
            '1' => { type: 'guest', guest_name: 'Dave', score: 20 }
          }
        }
      }

      expect(response).to redirect_to(game_sessions_path)
      follow_redirect!
      expect(response.body).to include('Session logged successfully.')

      game_session = GameSession.last
      expect(game_session.creator).to eq(alice)
      expect(game_session.game_session_participants.count).to eq(3)
    end

    it 'creates a solo session (logger only)' do
      post game_sessions_path, params: {
        game_session: {
          game_id: game.id,
          creator_score: 100
        }
      }

      expect(response).to redirect_to(game_sessions_path)
      expect(GameSession.last.game_session_participants.count).to eq(1)
    end

    it 're-renders on invalid game' do
      post game_sessions_path, params: {
        game_session: {
          game_id: 0,
          creator_score: 10
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Selected game not found')
    end

    it 're-renders when tagging a non-friend' do
      post game_sessions_path, params: {
        game_session: {
          game_id: game.id,
          creator_score: 10,
          players: {
            '0' => { type: 'friend', user_id: carol.id, score: 5 }
          }
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('not your friends')
    end
  end

  describe 'GET /game_sessions/:id' do
    before { sign_in_as(alice) }

    it 'shows a visible session' do
      session = create(:game_session, creator: alice, game: game)
      create(:game_session_participant, :confirmed, game_session: session, user: alice, score: 10)

      get game_session_path(session)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Catan')
      expect(response.body).to include('10 pts')
    end

    it 'returns 404 for a non-visible session' do
      other_user = create(:user)
      session = create(:game_session, creator: other_user, game: game)
      create(:game_session_participant, :confirmed, game_session: session, user: other_user, score: 5)

      get game_session_path(session)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /game_sessions/:id/edit' do
    before { sign_in_as(alice) }

    it 'renders edit form for the creator' do
      session = create(:game_session, creator: alice, game: game)
      create(:game_session_participant, :confirmed, game_session: session, user: alice, score: 10)

      get edit_game_session_path(session)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Edit Session')
    end

    it 'includes guest participants in the edit form' do
      session = create(:game_session, creator: alice, game: game)
      create(:game_session_participant, :confirmed, game_session: session, user: alice, score: 10)
      create(:game_session_participant, :guest, :confirmed, game_session: session, guest_name: 'Carol', score: 12)

      get edit_game_session_path(session)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Carol')
    end

    it 'returns 404 for non-creator' do
      session = create(:game_session, creator: bob, game: game)
      create(:game_session_participant, :confirmed, game_session: session, user: bob, score: 10)

      get edit_game_session_path(session)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /game_sessions/:id' do
    before { sign_in_as(alice) }

    let(:session) { create(:game_session, creator: alice, game: game) }

    before do
      create(:game_session_participant, :confirmed, game_session: session, user: alice, score: 10)
    end

    it 'updates the session and redirects' do
      new_game = create(:game, name: 'Ticket to Ride')

      patch game_session_path(session), params: {
        game_session: {
          game_id: new_game.id,
          creator_score: 99
        }
      }

      expect(response).to redirect_to(game_session_path(session))
      expect(session.reload.game_id).to eq(new_game.id)
      expect(session.game_session_participants.find_by!(user: alice).score).to eq(99)
      follow_redirect!
      expect(response.body).to include('Session updated successfully.')
    end

    it 'keeps guests when updating other session fields' do
      guest = create(:game_session_participant, :guest, :confirmed,
                     game_session: session, guest_name: 'Carol', score: 12)

      patch game_session_path(session), params: {
        game_session: {
          game_id: game.id,
          creator_score: 42,
          players: {
            '0' => {
              id: guest.id,
              type: 'guest',
              guest_name: 'Carol',
              score: 12
            }
          }
        }
      }

      expect(response).to redirect_to(game_session_path(session))
      expect(guest.reload).to have_attributes(guest_name: 'Carol', score: 12)
      expect(session.game_session_participants.find_by(user: alice).score).to eq(42)
    end

    it 'returns 404 for non-creator and leaves the session unchanged' do
      sign_out
      sign_in_as(bob)

      original_game_id = session.game_id
      original_score = session.game_session_participants.find_by!(user: alice).score
      other_game = create(:game, name: 'Ticket to Ride')

      patch game_session_path(session), params: {
        game_session: { game_id: other_game.id, creator_score: 50 }
      }

      expect(response).to have_http_status(:not_found)
      expect(session.reload.game_id).to eq(original_game_id)
      expect(session.game_session_participants.find_by!(user: alice).score).to eq(original_score)
    end
  end

  describe 'authentication' do
    it 'redirects unauthenticated users to sign in' do
      get game_sessions_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe 'nav badge' do
    it 'shows the notification count when authenticated' do
      participant = create(:game_session_participant, user: alice)
      create(:notification, recipient: alice, notifiable: participant)
      create(:notification, recipient: alice, notifiable: participant)

      sign_in_as(alice)
      get root_path

      expect(response.body).to include('Notifications')
      expect(response.body).to match(/indicator-item badge badge-primary badge-sm[^>]*>2</)
    end

    it 'hides the notification badge when there are no unread notifications' do
      sign_in_as(alice)
      get root_path

      body = response.body
      notifications_section = body[body.index('Notifications')..body.index('Notifications') + 200]
      expect(notifications_section).not_to include('indicator-item badge badge-primary badge-sm')
    end
  end
end
