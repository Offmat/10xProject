require 'rails_helper'
require 'rake'

RSpec.describe 'game_catalog:import', type: :task do
  before do
    Rails.application.load_tasks
    Rake::Task['game_catalog:import'].reenable
  end

  it 'invokes ImportService and prints results' do
    result = { created: 3, updated: 0, skipped: 0, warnings: [] }
    expect(GameCatalog::ImportService).to receive(:call).and_return(result)

    expect { Rake::Task['game_catalog:import'].invoke }.to output("Games: 3 created, 0 updated, 0 skipped\n").to_stdout
  end

  it 'prints warnings when present' do
    result = { created: 1, updated: 0, skipped: 1, warnings: [ 'Entity Q999 not returned' ] }
    allow(GameCatalog::ImportService).to receive(:call).and_return(result)

    expect { Rake::Task['game_catalog:import'].invoke }.to output(/WARN: Entity Q999 not returned/).to_stdout
  end
end
