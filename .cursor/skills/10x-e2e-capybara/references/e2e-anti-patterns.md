# Five Agent E2E Anti-Patterns

Review every generated Capybara system spec against these five names. Do not
accept a test merely because it is green.

## 1. Hallucinated assertion

The example logs a session and then checks only:

```ruby
expect(page).to have_content('Session logged successfully.')
```

That does not prove the submitted friend and guest were persisted.

**Fix:** assert the observable result and query the created `GameSession` to
verify the participant identities, scores, and statuses. Ask whether the
assertion fails when the named risk materializes.

## 2. Brittle selector

This couples the test to presentation:

```ruby
find('.btn-primary').click
find('div.player-row:nth-child(2) input:nth-child(4)').fill_in(with: 30)
```

**Fix:** prefer `click_button`, `fill_in`, `select`, `choose`, and waiting
matchers against labels or visible text. When repeated nested fields genuinely
lack usable labels, use the sanctioned exception from the seed: an attribute
finder inside a narrow `within` block, such as
`within(row) { find('[name$="[score]"]').fill_in(with: 30) }`. This is not a
blanket CSS-selector allowance.

## 3. Shared state between tests

An "edit session" example assumes another example already created the session.
RSpec order changes, retries, or parallel execution then make it fail.

**Fix:** each example creates its own users, friendships, game, and session
state; authenticates; performs the action; and asserts the outcome.

## 4. Wait-for-time

```ruby
click_button '+ Add player'
sleep 3
```

The delay may be longer than needed locally and too short in CI.

**Fix:** wait for the state Stimulus should produce:

```ruby
click_button '+ Add player'
expect(page).to have_css('[data-nested-form-row]', count: 1)
```

Capybara matchers retry up to `default_max_wait_time`.

## 5. No cleanup

Hard-coded unique values can collide on rerun, and browser-visible state outside
the database may survive an example.

**Fix:** generate unique data with `SecureRandom`, rely on the configured Rails
system-spec transaction strategy where it applies, and explicitly clean up
external or non-transactional state. Every example must be safe to run twice.

## Re-prompt discipline

Never say only "fix this test." Name the anti-pattern, explain why it fails to
protect the risk or causes false failures, and state the replacement pattern.

### Re-prompt examples

```text
Hallucinated assertion: the spec checks only the success flash, so it stays
green if a submitted guest is silently dropped. Assert the persisted friend and
guest participant records, including scores, so Risk #2 makes the spec fail.
```

```text
Brittle selector: find('.btn-primary') couples the spec to styling. Replace it
with click_button 'Log Session'. For the unlabeled repeated score input, scope
the seed's [name$="[score]"] finder inside the relevant player-row within block.
```

```text
Wait-for-time: sleep 3 guesses when Stimulus has added the row and will flake
under variable CI load. Replace it with have_css on the expected player-row
count, then interact after that matcher succeeds.
```

```text
Shared state between tests: this example depends on a session created by another
example. Create all records and authenticate with sign_in_as inside this example
so it runs alone and in any order.
```

```text
No cleanup: the spec uses a fixed guest name and collides on rerun. Generate a
unique name and ensure any non-transactional state is removed by this example.
```
