# frozen_string_literal: true

# Production-only error monitoring. Evaluated on every boot (including Docker
# assets:precompile under RAILS_ENV=production) — both guards are required so a
# missing DSN keeps the SDK inert at build time. Do not add ARG SENTRY_DSN.
return unless Rails.env.production? && ENV['SENTRY_DSN'].present?

Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.send_default_pii = false
end
