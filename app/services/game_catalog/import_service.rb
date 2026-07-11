module GameCatalog
  class ImportService
    def self.call(seed_file: Rails.root.join('db/seeds/mvp_seed_list.yml'))
      new.call(seed_file:)
    end

    def call(seed_file:)
      seed_entries = YAML.load_file(seed_file)
      wikidata_ids = seed_entries.pluck('wikidata_id')
      seed_names = seed_entries.each_with_object({}) { |entry, hash| hash[entry['wikidata_id']] = entry['name'] }

      bindings = WikidataClient.fetch(wikidata_ids:)
      game_attrs_list = WikidataMapper.call(bindings, seed_names:)

      result = { created: 0, updated: 0, skipped: 0, warnings: [] }
      returned_ids = game_attrs_list.map { |a| a[:wikidata_id] }

      (wikidata_ids - returned_ids).each do |missing_id|
        result[:skipped] += 1
        result[:warnings] << "Entity #{missing_id} not returned by Wikidata API"
      end

      game_attrs_list.each { |attrs| persist_game(attrs, result) }

      result
    end

    private

    def persist_game(attributes, result)
      game = Game.find_or_initialize_by(wikidata_id: attributes[:wikidata_id])
      was_new = game.new_record?

      game.assign_attributes(attributes.merge(imported_at: Time.current))

      if game.save
        was_new ? result[:created] += 1 : result[:updated] += 1
      else
        result[:skipped] += 1
        message = "Skipped #{attributes[:wikidata_id]}: #{game.errors.full_messages.join(', ')}"
        result[:warnings] << message
        Rails.logger.warn("[game_catalog] #{message}")
      end
    end
  end
end
