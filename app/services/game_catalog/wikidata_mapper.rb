module GameCatalog
  class WikidataMapper
    def self.call(bindings, seed_names: {})
      new(seed_names:).call(bindings)
    end

    def initialize(seed_names: {})
      @seed_names = seed_names
    end

    def call(bindings)
      grouped = group_by_game(bindings)

      grouped.map do |wikidata_id, rows|
        row = rows.first
        {
          wikidata_id: wikidata_id,
          name: string_value(row, 'gameLabel') || seed_names[wikidata_id],
          description: string_value(row, 'gameDescription'),
          bgg_id: string_value(row, 'bggId'),
          min_players: integer_value(row, 'minPlayers'),
          max_players: integer_value(row, 'maxPlayers'),
          year_published: year_from_date(row, 'pubDate'),
          play_time_minutes: integer_value(row, 'playTime'),
          source: 'wikidata'
        }
      end
    end

    private

    attr_reader :seed_names

    def group_by_game(bindings)
      bindings.group_by { |row| qid(row) }
    end

    def qid(row)
      row.dig('game', 'value')&.split('/')&.last
    end

    def string_value(row, field)
      row.dig(field, 'value')
    end

    def integer_value(row, field)
      val = row.dig(field, 'value')
      val&.to_i
    end

    def year_from_date(row, field)
      val = row.dig(field, 'value')
      val&.match(/(\d{4})/)&.captures&.first&.to_i
    end
  end
end
