require 'capybara/cuprite'

Capybara.default_max_wait_time = 5
Capybara.ignore_hidden_elements = true
Capybara.server = :puma, { Silent: true }
Capybara.save_path = Rails.root.join('tmp/screenshots').to_s

RSpec.configure do |config|
  config.before(:each, type: :system) do
    # Options MUST go through driven_by(... options:). Rails' SystemTestCase
    # re-registers :cuprite and ignores a prior Capybara.register_driver block.
    #
    # Headed mode (HEADLESS=0) is intentionally not supported here: Chrome 152 +
    # Ferrum 0.18 fails with "Failed to find browser context" on page attach
    # (setDownloadBehavior / ferrum#546), and Cursor's process coalition aborts
    # headed NSApplication. Use headless + tmp/screenshots for local inspection.
    browser_options = {}
    browser_options['no-sandbox'] = nil if ENV['CI']

    options = {
      headless: true,
      js_errors: false,
      browser_options: browser_options
    }

    # CI failure artifacts: GHA uploads tmp/screenshots + this Ferrum/CDP log.
    if ENV['CI']
      FileUtils.mkdir_p(Rails.root.join('tmp'))
      options[:logger] = File.open(Rails.root.join('tmp/ferrum-stderr.log'), 'a')
    end

    driven_by :cuprite, screen_size: [1400, 900], options: options
  end
end
