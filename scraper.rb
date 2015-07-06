#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'json'
require 'fuzzy_match'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def candidates
  data = open("https://api.morph.io/tmtmtmtm/lesotho-electoral-commission/data.json?query=select%20*%20from%20data&key=" + CGI.escape(ENV["MORPH_API_KEY"])).read
  JSON.parse(data, symbolize_names: true)
end

def find_candidate(data)
  matches = @candidates.find_all { |c| c[:constituency_id] == data[:area_id].to_i }.each do |c|
    c[:name] = "#{c[:given_name]} #{c[:family_name]}"
  end
  match = FuzzyMatch.new(matches.map { |m| m[:name] }).find(data[:name]) or return
  return matches.find { |m| m[:name] == match }
end


def scrape_list(url)
  noko = noko_for(url)
  noko.css('#ja-content table tr').drop(1).each do |row|
    tds = row.css('td')
    data = { 
      name: tds[0].text.sub('Mohl. ','').strip,
      area: tds[1].text.strip,
      area_id: tds[2].text.strip,
      party: tds[3].text.strip,
      term: 9,
      source: url,
    }
    next if data[:name].empty?
    if data[:party].to_s.empty? and candidate = find_candidate(data) 
      data[:party] = candidate[:party]
      data[:gender] = candidate[:gender]
      data[:age] = candidate[:age]
    end
    puts data
    ScraperWiki.save_sqlite([:name, :term], data)
  end
end

term = {
  id: 9,
  name: '9th Parliament',
  start_date: '2015-03-10',
  source: 'http://www.parliament.ls/assembly/index.php?option=com_content&view=article&id=143:10th-march-2015&catid=61:hansard&Itemid=70',
}
ScraperWiki.save_sqlite([:id], term, 'terms')

@candidates = candidates
scrape_list('http://www.parliament.ls/assembly/index.php?option=com_content&view=article&id=37&Itemid=56')
