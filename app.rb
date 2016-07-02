require 'bundler/setup'
Bundler.require
Dotenv.load

require 'open-uri'
require 'json'
require 'pry'
require 'everypolitician'
require 'everypolitician/popolo'

module EveryPolitician
  class Legislature
    def clear_popolo
      @popolo = nil
    end
  end
end

class GenderStats
  def self.report
    gender_stats = []
    EveryPolitician.countries.each do |c|
      country = {
        slug: c.slug,
      }
      legislatures = []
      c.legislatures.each do |l|
        totals_seen = {}
        totals = {
          overall: Hash.new(0),
          parties: Hash.new { | hash, key | hash[key] = Hash.new(0) },
        }
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

        party_id_to_name = {}
        l.popolo.organizations.where(classification: 'party').each do |p|
          party_id_to_name[p.id] = p.name
        end

        l.popolo.persons.each do |p|
          gender = p.gender || 'unknown'
          if not totals_seen[p.id]
              totals[:overall][gender] += 1
              totals[:overall][:total] += 1
              totals_seen[p.id] = gender
          elsif totals_seen[p.id] != gender and gender != 'unknown'
              totals[:overall][gender] += 1
              totals[:overall][totals_seen[p.id]] -= 1
              totals_seen[p.id] = gender
          end
          person_memberships[p.id].each do |m|
            term_id = m.document[:legislative_period_id]
            terms[term_id][:overall][gender] += 1
            terms[term_id][:overall][:total] += 1
            group_id = m.on_behalf_of_id
            group = l.popolo.organizations.find { |o| o.id == group_id }
            wikidata_identifier = ((group[:identifiers] || {}).find { |i| i[:scheme] == 'wikidata' } || {})[:identifier]
            if wikidata_identifier
              party = wikidata_identifier
            else
              party = group_id
            end
            terms[term_id][:parties][party][:name] = party_id_to_name[group_id]
            terms[term_id][:parties][party][gender] += 1
            terms[term_id][:parties][party][:total] += 1
            party_person = party + ':' + p.id
            if not totals_seen[party_person]
                totals[:parties][party][:name] = party_id_to_name[group_id]
                totals[:parties][party][gender] += 1
                totals[:parties][party][:total] += 1
                totals_seen[party_person] = gender
            elsif totals_seen[party_person] != gender and gender != 'unknown'
                totals[:overall][party][gender] += 1
                totals[:overall][party][totals_seen[party_person]] -= 1
                totals_seen[party_person] = gender
            end
          end
        end

        legislature[:terms] = terms
        legislature[:totals] = totals
        legislatures.push(legislature)
        l.clear_popolo
      end
      country[:legislatures] = legislatures
      gender_stats.push(country)
    end
    gender_stats
  end
end

class GBCountryStatsGenerator
  include Sidekiq::Worker
  include Everypoliticianbot::Github

  def perform(countries_json_url)
    Everypolitician.countries_json = countries_json_url
    with_git_repo('everypolitician/gender-balance-country-stats', branch: 'gh-pages', message: 'Update stats.json') do
      File.write('stats.json', JSON.pretty_generate(GenderStats.report))
    end
  end
end

post '/' do
  everypolitician_event = request.env['HTTP_X_EVERYPOLITICIAN_EVENT']
  if everypolitician_event == 'pull_request_merged'
    request.body.rewind
    payload = JSON.parse(request.body.read, symbolize_names: true)
    job_id = GBCountryStatsGenerator.perform_async(payload[:countries_json_url])
    "Queued job #{job_id}"
  else
    "Unhandled event #{everypolitician_event}"
  end
end

get '/' do
  'This is gender-balance-country-stats, waiting to receive a webhook POST request to this URL.'
end
