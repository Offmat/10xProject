require 'rails_helper'

RSpec.describe 'Rails application' do
  it 'loads in the test environment' do
    expect(Rails.env).to eq('test')
    expect(Rails.version).to start_with('8.1')
  end
end
