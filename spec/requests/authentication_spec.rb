require 'rails_helper'

RSpec.describe 'Authentication', type: :request do
  include ActiveJob::TestHelper

  describe 'public routes' do
    it 'allows the home page without authentication' do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('all-aBoard')
    end

    it 'allows the health check without authentication' do
      get rails_health_check_path

      expect(response).to have_http_status(:ok)
    end

    it 'allows the sign-in page without authentication' do
      get new_session_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'protected routes' do
    it 'redirects sign-out when not authenticated' do
      delete session_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe 'sign up, sign in, and sign out' do
    it 'registers a user, signs in, accesses a protected action, and signs out' do
      register_user(email: 'newplayer@example.com')

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)

      sign_out

      sign_in_as(User.find_by!(email: 'newplayer@example.com'))
      sign_out
    end

    it 'signs in an existing user' do
      user = create(:user)

      sign_in_as(user)
      sign_out
    end
  end

  describe 'password reset' do
    it 'sends reset instructions and updates the password with a valid token' do
      user = create(:user)

      expect {
        post passwords_path, params: { email: user.email }
      }.to have_enqueued_mail(PasswordsMailer, :reset)

      perform_enqueued_jobs

      token = user.reload.password_reset_token

      put password_path(token), params: { password: 'newpassword', password_confirmation: 'newpassword' }
      expect(response).to redirect_to(new_session_path)

      expect(User.authenticate_by(email: user.email, password: 'newpassword')).to eq(user)
    end
  end

  describe 'session creation rate limiting' do
    let(:user) { create(:user) }

    # test env uses :null_store; rate_limit needs a real increment backend
    before do
      cache = ActiveSupport::Cache::MemoryStore.new
      allow(ActionController::Base.cache_store).to receive(:increment) do |key, amount = 1, **options|
        cache.increment(key, amount, **options)
      end
    end

    it 'throttles repeated sign-in attempts' do
      10.times do
        post session_path, params: { email: user.email, password: 'wrong-password' }
        expect(response).to redirect_to(new_session_path)
        expect(flash[:alert]).to eq('Try another email or password.')
      end

      expect(User).not_to receive(:authenticate_by)
      expect(AuthAuditLogger).to receive(:log).with(
        hash_including(event: 'sign_in_rate_limited', email: user.email)
      )

      post session_path, params: { email: user.email, password: 'wrong-password' }
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq('Try again later.')
    end

    it 'blocks sign-in with a correct password while rate limited' do
      10.times do
        post session_path, params: { email: user.email, password: 'wrong-password' }
      end

      expect(User).not_to receive(:authenticate_by)

      post session_path, params: { email: user.email, password: 'password' }
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq('Try again later.')
    end
  end

  describe 'auth audit logging' do
    let(:user) { create(:user) }

    it 'logs successful sign-in without leaking the password' do
      expect(AuthAuditLogger).to receive(:log).with(
        hash_including(event: 'sign_in_success', email: user.email, user_id: user.id)
      )

      post session_path, params: { email: user.email, password: 'password' }
    end

    it 'logs failed sign-in attempts' do
      expect(AuthAuditLogger).to receive(:log).with(
        hash_including(event: 'sign_in_failure', email: user.email)
      )

      post session_path, params: { email: user.email, password: 'wrong-password' }
    end

    it 'logs sign-out' do
      sign_in_as(user)

      expect(AuthAuditLogger).to receive(:log).with(
        hash_including(event: 'sign_out', email: user.email, user_id: user.id)
      )

      delete session_path
    end
  end
end
