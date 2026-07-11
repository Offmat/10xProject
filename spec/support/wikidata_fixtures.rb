module WikidataFixtures
  def wikidata_fixture(name)
    File.read(Rails.root.join('spec', 'fixtures', 'wikidata', "#{name}.json"))
  end

  def parsed_wikidata_fixture(name)
    JSON.parse(wikidata_fixture(name))
  end
end
