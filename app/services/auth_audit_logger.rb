class AuthAuditLogger
  def self.log(event:, email: nil, user_id: nil, ip: nil, user_agent: nil)
    payload = {
      event: event,
      email: email,
      user_id: user_id,
      ip: ip,
      user_agent: user_agent,
      at: Time.current.iso8601
    }.compact

    Rails.logger.info("[auth_audit] #{payload.to_json}")
  end
end
