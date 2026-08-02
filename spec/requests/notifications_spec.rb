require 'rails_helper'

RSpec.describe 'Notifications', type: :request do
  let(:alice) { create(:user, email: 'alice@example.com') }
  let(:bob) { create(:user, email: 'bob@example.com') }
  let(:game) { create(:game, name: 'Catan') }

  describe 'GET /notifications' do
    before { sign_in_as(alice) }

    it 'lists unread notifications for the current user' do
      session = create(:game_session, creator: bob, game: game)
      participant = create(:game_session_participant, game_session: session, user: alice, score: 25)
      create(:notification, recipient: alice, notifiable: participant)

      get notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Catan')
      expect(response.body).to include(bob.email)
      expect(response.body).to include('25')
      expect(response.body).to include('Confirm')
      expect(response.body).to include('Reject')
    end

    it 'does not list read notifications' do
      session = create(:game_session, creator: bob, game: game)
      participant = create(:game_session_participant, game_session: session, user: alice, score: 25)
      create(:notification, recipient: alice, notifiable: participant, read_at: Time.current)

      get notifications_path

      expect(response.body).not_to include('Catan')
      expect(response.body).to include('all caught up')
    end

    it 'shows empty state when no notifications exist' do
      get notifications_path

      expect(response.body).to include('all caught up')
    end
  end

  describe 'PATCH /notifications/:id/confirm' do
    before { sign_in_as(alice) }

    it 'confirms the participant, marks notification read, and redirects' do
      session = create(:game_session, creator: bob, game: game)
      participant = create(:game_session_participant, game_session: session, user: alice, score: 30)
      notification = create(:notification, recipient: alice, notifiable: participant)

      patch confirm_notification_path(notification)

      expect(response).to redirect_to(notifications_path)
      follow_redirect!
      expect(response.body).to include('Session confirmed.')

      expect(participant.reload).to be_confirmed
      expect(notification.reload.read_at).not_to be_nil
    end

    it 'includes the session on the friend history index after confirm' do
      session = create(:game_session, creator: bob, game: game)
      participant = create(:game_session_participant, game_session: session, user: alice, score: 30)
      notification = create(:notification, recipient: alice, notifiable: participant)

      patch confirm_notification_path(notification)
      expect(response).to redirect_to(notifications_path)

      get game_sessions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Catan')
    end

    it 'returns 404 when acting on another user notification' do
      session = create(:game_session, creator: alice, game: game)
      participant = create(:game_session_participant, game_session: session, user: bob, score: 15)
      notification = create(:notification, recipient: bob, notifiable: participant)

      patch confirm_notification_path(notification)

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when the notification is already read and leaves status unchanged' do
      session = create(:game_session, creator: bob, game: game)
      participant = create(:game_session_participant, :confirmed, game_session: session, user: alice, score: 30)
      notification = create(:notification, recipient: alice, notifiable: participant, read_at: Time.current)

      patch confirm_notification_path(notification)

      expect(response).to have_http_status(:not_found)
      expect(participant.reload).to be_confirmed
    end
  end

  describe 'PATCH /notifications/:id/reject' do
    before { sign_in_as(alice) }

    it 'rejects the participant, marks notification read, and redirects' do
      session = create(:game_session, creator: bob, game: game)
      participant = create(:game_session_participant, game_session: session, user: alice, score: 30)
      notification = create(:notification, recipient: alice, notifiable: participant)

      patch reject_notification_path(notification)

      expect(response).to redirect_to(notifications_path)
      follow_redirect!
      expect(response.body).to include('Session rejected.')

      expect(participant.reload).to be_rejected
      expect(notification.reload.read_at).not_to be_nil
    end

    it 'excludes the session from the friend history index after reject' do
      rejected_session = create(:game_session, creator: bob, game: game)
      participant = create(:game_session_participant, game_session: rejected_session, user: alice, score: 30)
      notification = create(:notification, recipient: alice, notifiable: participant)

      patch reject_notification_path(notification)
      expect(response).to redirect_to(notifications_path)

      get game_sessions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Catan')
    end

    it 'keeps the session on the logger history index after the friend rejects' do
      rejected_session = create(:game_session, creator: bob, game: game)
      participant = create(:game_session_participant, game_session: rejected_session, user: alice, score: 30)
      notification = create(:notification, recipient: alice, notifiable: participant)

      patch reject_notification_path(notification)
      expect(response).to redirect_to(notifications_path)

      sign_out
      sign_in_as(bob)
      get game_sessions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Catan')
    end

    it 'returns 404 when acting on another user notification' do
      session = create(:game_session, creator: alice, game: game)
      participant = create(:game_session_participant, game_session: session, user: bob, score: 15)
      notification = create(:notification, recipient: bob, notifiable: participant)

      patch reject_notification_path(notification)

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when the notification is already read and leaves status unchanged' do
      session = create(:game_session, creator: bob, game: game)
      participant = create(:game_session_participant, :confirmed, game_session: session, user: alice, score: 30)
      notification = create(:notification, recipient: alice, notifiable: participant, read_at: Time.current)

      patch reject_notification_path(notification)

      expect(response).to have_http_status(:not_found)
      expect(participant.reload).to be_confirmed
    end
  end

  describe 'authentication' do
    it 'redirects unauthenticated users to sign in' do
      get notifications_path

      expect(response).to redirect_to(new_session_path)
    end
  end
end
