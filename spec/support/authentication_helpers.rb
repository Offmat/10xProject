module AuthenticationHelpers
  DEFAULT_PASSWORD = 'password'

  def sign_in_as(user, password: DEFAULT_PASSWORD)
    if system_spec?
      sign_in_as_system(user)
    else
      post session_path, params: { email: user.email, password: password }
      expect(response).to have_http_status(:redirect)
      follow_redirect!
    end
  end

  def sign_out
    if system_spec?
      page.driver.remove_cookie('session_id') if page.driver.respond_to?(:remove_cookie)
      visit new_session_path
    else
      delete session_path
      expect(response).to redirect_to(new_session_path)
    end
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

  private

  def system_spec?
    RSpec.current_example.metadata[:type] == :system
  end

  def sign_in_as_system(user)
    session = user.sessions.create!(user_agent: 'Capybara', ip_address: '127.0.0.1')
    visit new_session_path

    jar = ActionDispatch::Cookies::CookieJar.build(ActionDispatch::TestRequest.create, {})
    jar.signed[:session_id] = session.id
    page.driver.set_cookie('session_id', jar[:session_id], path: '/')
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :system
end
