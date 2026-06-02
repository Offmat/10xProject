require 'rails_helper'

RSpec.describe AuthAuditLogger do
  describe '.log' do
    it 'emits structured auth audit entries without secrets' do
      expect(Rails.logger).to receive(:info) do |message|
        expect(message).to start_with('[auth_audit] ')
        payload = JSON.parse(message.delete_prefix('[auth_audit] '))
        expect(payload).to include(
          'event' => 'sign_in_success',
          'email' => 'player@example.com',
          'user_id' => 42,
          'ip' => '127.0.0.1',
          'user_agent' => 'RSpec'
        )
        expect(payload).not_to include('password')
      end

      described_class.log(
        event: 'sign_in_success',
        email: 'player@example.com',
        user_id: 42,
        ip: '127.0.0.1',
        user_agent: 'RSpec'
      )
    end
  end
end
