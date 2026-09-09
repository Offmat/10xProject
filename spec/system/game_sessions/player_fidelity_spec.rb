# frozen_string_literal: true

require 'rails_helper'

# Fidelity seed for test-plan.md risks #1–#2 (multi-player form POST / Stimulus rows).
# Asserts persisted participants match what the browser submitted — not flash alone.
RSpec.describe 'Game session player fidelity', type: :system do
  it 'persists submitted friend and guest players after log session' do
    logger = create(:user)
    friend = create(:user)
    game = create(:game, name: 'Catan')
    create(:friendship, :accepted, requester: logger, addressee: friend)

    guest_name = "Guest #{Time.current.to_i}-#{SecureRandom.hex(4)}"
    creator_score = 42
    friend_score = 30
    guest_score = 20

    sign_in_as(logger)
    visit new_game_session_path

    select game.name, from: 'Game'
    fill_in 'Your score', with: creator_score

    click_button '+ Add player'
    expect(page).to have_css('[data-nested-form-row]', count: 1)

    within(all('[data-nested-form-row]').last) do
      choose 'Friend'
      find('select[name$="[user_id]"]').select(friend.email)
      find('[name$="[score]"]').fill_in(with: friend_score)
    end

    click_button '+ Add player'
    expect(page).to have_css('[data-nested-form-row]', count: 2)

    within(all('[data-nested-form-row]').last) do
      choose 'Guest'
      fill_in 'Guest name', with: guest_name
      find('[name$="[score]"]').fill_in(with: guest_score)
    end

    click_button 'Log Session'

    expect(page).to have_content('Session logged successfully.')
    expect(page).to have_content(game.name)
    expect(page).to have_content(friend.email)
    expect(page).to have_content(guest_name)

    game_session = GameSession.order(:id).last
    participants = game_session.game_session_participants

    expect(participants.size).to eq(3)

    logger_p = participants.find_by!(user: logger)
    expect(logger_p).to have_attributes(score: creator_score, status: 'confirmed')

    friend_p = participants.find_by!(user: friend)
    expect(friend_p).to have_attributes(score: friend_score, status: 'pending')

    guest_p = participants.find_by!(guest_name: guest_name)
    expect(guest_p).to have_attributes(score: guest_score, status: 'confirmed')
  end
end
