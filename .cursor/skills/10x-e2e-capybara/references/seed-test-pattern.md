# Seed System Spec Pattern

The live seed exemplar for this project is
`spec/system/game_sessions/player_fidelity_spec.rb`. Read that file before
writing a new system spec and model new tests on its current conventions.
**What the seed demonstrates is what generated specs reproduce.**

## Patterns the seed establishes

- Require `rails_helper`, declare `type: :system`, and keep the example
  independently runnable.
- Authenticate with `sign_in_as(user)`. The helper installs a signed session
  cookie through Cuprite; setup must not fill in the login UI.
- Prefer Capybara's user-facing APIs: `click_button`, `fill_in`,
  `select ... from:`, and `choose`.
- Assert rendered state with waiting matchers such as `have_content`,
  `have_button`, `have_field`, `have_select`, and `have_css`. Never use `sleep`.
- Use unique data so retries and parallel runs do not collide.
- Assert the persisted business outcome in the database, not only a flash
  message.

## Cuprite + Hotwire

Stimulus adds player rows asynchronously. After `click_button '+ Add player'`,
wait for the new row with a Capybara matcher before interacting with it:

```ruby
click_button '+ Add player'
expect(page).to have_css('[data-nested-form-row]', count: 1)
```

Capybara matchers retry up to `Capybara.default_max_wait_time`; fixed sleeps are
both slower and flaky.

## Sanctioned scoped-attribute exception

Labels and button text remain the default locator strategy. The player form
currently has repeated nested controls without a usable unique label, so a
scoped attribute finder inside `within` is the sanctioned exception:

```ruby
within(all('[data-nested-form-row]').last) do
  choose 'Friend'
  find('select[name$="[user_id]"]').select(friend.email)
  find('[name$="[score]"]').fill_in(with: friend_score)
end
```

This is the player-row pattern used by the live seed. It is not permission to
use broad CSS selectors or DOM-position selectors elsewhere.

## Shortened exemplar

```ruby
require 'rails_helper'

RSpec.describe 'Game session player fidelity', type: :system do
  it 'persists submitted friend and guest players' do
    logger = create(:user)
    friend = create(:user)
    game = create(:game, name: 'Catan')
    create(:friendship, :accepted, requester: logger, addressee: friend)
    guest_name = "Guest #{SecureRandom.hex(4)}"

    sign_in_as(logger)
    visit new_game_session_path
    select game.name, from: 'Game'
    fill_in 'Your score', with: 42

    click_button '+ Add player'
    expect(page).to have_css('[data-nested-form-row]', count: 1)
    within(all('[data-nested-form-row]').last) do
      choose 'Friend'
      find('select[name$="[user_id]"]').select(friend.email)
      find('[name$="[score]"]').fill_in(with: 30)
    end

    click_button '+ Add player'
    expect(page).to have_css('[data-nested-form-row]', count: 2)
    within(all('[data-nested-form-row]').last) do
      choose 'Guest'
      fill_in 'Guest name', with: guest_name
      find('[name$="[score]"]').fill_in(with: 20)
    end

    click_button 'Log Session'
    expect(page).to have_content('Session logged successfully.')

    session = GameSession.order(:id).last
    expect(session.game_session_participants.find_by!(user: friend).score).to eq(30)
    expect(session.game_session_participants.find_by!(guest_name: guest_name).score).to eq(20)
  end
end
```

The live seed is authoritative if this shortened example and the application
later diverge.
