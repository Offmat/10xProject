module AuthenticationHelpers
  DEFAULT_PASSWORD = 'password'

  def sign_in_as(user, password: DEFAULT_PASSWORD)
    if system_spec?
      # System specs sign in by cookie, so a custom password would be ignored
      # and the example would pass for the wrong reason.
      raise ArgumentError, 'system sign_in_as ignores password:; use a request spec' unless password == DEFAULT_PASSWORD

      sign_in_as_system(user)
    else
      post session_path, params: { email: user.email, password: password }
      expect(response).to have_http_status(:redirect)
      follow_redirect!
    end
  end

  def sign_out
    if system_spec?
      sign_out_system
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
    @system_session = user.sessions.create!(user_agent: 'Capybara', ip_address: '127.0.0.1')
    visit new_session_path

    jar = ActionDispatch::Cookies::CookieJar.build(ActionDispatch::TestRequest.create, {})
    jar.signed[:session_id] = @system_session.id
    # Escape to mirror Rails' write path: the app reads through
    # Rack::Utils.parse_cookies_header, which unescapes (`+` becomes a space).
    page.driver.set_cookie('session_id', Rack::Utils.escape(jar[:session_id]), path: '/')
  end

  # Mirrors production's terminate_session: drop the cookie *and* the record.
  def sign_out_system
    @system_session&.destroy
    @system_session = nil
    page.driver.remove_cookie('session_id')
    visit new_session_path
    expect(page).to have_link('Sign in')
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :system
end
