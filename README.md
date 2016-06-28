# gender-balance-country-stats

A little app that generates summary data about gender breakdown in
legislatures around the world based on data from
[GenderBalance](http://gender-balance.org) and
[EveryPolitician project](http://everypolitician.org).

### About the data

The data is available in the `gh-pages` branch of this repository in the
[stats.json](https://raw.githubusercontent.com/everypolitician/gender-balance-country-stats/gh-pages/stats.json) file.

It's a JSON array of Hashes, one for each country. Within the country
hash there is a `legislatures` array which has a `terms` hash with one
entry for each term we have details for and a `totals` hash which has
counts across all terms that we have details for.

In these totals if someone is listed in one term as unknown and
another with a confirmed gender, they will be counted under the
confirmed gender.

Each of these also contain breakdowns per party. Note that it's possible
that a person could be counted twice in the party data if they have
changed party.

The country, assembly and party data is keyed using the slugs from the
EverPolitician Popolo data.
