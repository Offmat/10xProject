module AuthenticationHelpers
  def sign_in_as(user, password: 'password')
    post session_path, params: { email: user.email, password: password }
    expect(response).to have_http_status(:redirect)
    follow_redirect!
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
