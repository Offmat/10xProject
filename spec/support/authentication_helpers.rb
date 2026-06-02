module AuthenticationHelpers
  DEFAULT_PASSWORD = 'password'

  def sign_in_as(user, password: DEFAULT_PASSWORD)
    post session_path, params: { email: user.email, password: password }
    expect(response).to have_http_status(:redirect)
    follow_redirect!
  end

  def sign_out
    delete session_path
    expect(response).to redirect_to(new_session_path)
  end

  def register_user(email:, password: DEFAULT_PASSWORD, password_confirmation: password)
    post users_path, params: {
      user: {
        email: email,
        password: password,
        password_confirmation: password_confirmation
      }
    }
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
