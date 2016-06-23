require 'open-uri'
require 'json'
require 'everypolitician'
require 'everypolitician/popolo'

gender_stats = []
EveryPolitician.countries.each do |c|
  country = {
    slug: c.slug,
  }
  legislatures = []
  c.legislatures.each do |l|
    legislature = {
      slug: l.slug,
      term: l.raw_data[:term],
    }
    stats = {
      overall: Hash.new(0),
      parties: {},
    }
    legislature_data = l.popolo
    legislature_data.organizations.where(classification: "party").each do |o|
      stats[:parties][o.id] = Hash.new(0)
    end
    legislature_data.memberships.each do |m|
      person = legislature_data.persons.find_by(id: m.person_id)
      gender = person.gender || 'unknown'
      stats[:overall][gender] += 1
      stats[:overall][:total] += 1
      party = m.on_behalf_of_id
      stats[:parties][party][gender] += 1
      stats[:parties][party][:total] += 1
    end
    legislature[:stats] = stats
    legislatures.push(legislature)
  end
  country[:legislatures] = legislatures
  gender_stats.push(country)
end

File.open("stats.json","w") do |f|
  f.write(gender_stats.to_json)
end
