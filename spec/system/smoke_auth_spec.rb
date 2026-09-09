require 'rails_helper'

RSpec.describe 'System auth smoke', type: :system do
  it 'signs in via cookie and reaches authenticated chrome' do
    user = create(:user)

    sign_in_as(user)
    visit game_sessions_path

    expect(page).to have_button('Sign out')
    expect(page).to have_content(user.email)
    expect(page).to have_no_link('Sign in')
  end
end
