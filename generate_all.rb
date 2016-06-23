require 'open-uri'
require 'json'
require 'everypolitician'
require 'everypolitician/popolo'


# this is a bit of a kludge to make sure that we don't
# use all the memory
module EveryPolitician
  class Legislature
    def clear_popolo
      @popolo = nil
    end
  end
end

gender_stats = []
EveryPolitician.countries.each do |c|
  country = {
    slug: c.slug,
  }
  legislatures = []
  c.legislatures.each do |l|
    legislature = {
      slug: l.slug,
    }
    terms = {}

    l.popolo.events.where(classification: "legislative period").each do |lp|
      terms[lp.id] = {
        overall: Hash.new(0),
        parties: Hash.new { | hash, key | hash[key] = Hash.new(0) },
      }
    end

    person_memberships = Hash.new { | hash, key | hash[key] = [] }
    l.popolo.memberships.each do |m|
      person_memberships[m.person_id].push(m)
    end

    l.popolo.persons.each do |p|
      gender = p.gender || 'unknown'
      person_memberships[p.id].each do |m|
        term_id = m.document[:legislative_period_id]
        terms[term_id][:overall][gender] += 1
        terms[term_id][:overall][:total] += 1
        party = m.on_behalf_of_id
        terms[term_id][:parties][party][gender] += 1
        terms[term_id][:parties][party][:total] += 1
      end
    end

    legislature[:terms] = terms
    legislatures.push(legislature)
    l.clear_popolo
  end
  country[:legislatures] = legislatures
  gender_stats.push(country)
end

File.open("stats.json","w") do |f|
  f.write(gender_stats.to_json)
end
