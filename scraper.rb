#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def scrape_mp(url)
  noko = noko_for(url)
  data = { 
    image: noko.css('img[@src*="/people/"]').sort_by { |i| i.attr('width') }.first.attr('src'),
    facebook: noko.css('a.inside[@href*="facebook.com"]/@href').text,
  }
  data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?
  return data
end

def scrape_list(url)
  noko = noko_for(url)
  noko.css('a[href*="/constituencies/"]/@href').map(&:text).uniq.reject { |t| t.include? '/default' }.each do |constit|
    scrape_constituency URI.join(url, constit)
  end
end

def scrape_constituency(url)
  noko = noko_for(url)
  constituency = noko.css('.Article02').text
  puts constituency
  noko.xpath('.//span[@class="votes" and contains(.,"Representatives")]/ancestor::table[1]/tr[2]//table/tr').drop(1).each do |tr|
    tds = tr.css('td')
    data = { 
      name: tds[1].text.tidy,
      party: tds[2].text.tidy,
      term: tds[0].text.tidy,
      constituency: constituency,
      source: url.to_s,
    }
    mp_link = tds[1].css('a/@href')
    unless mp_link.to_s.empty?
      new_data = scrape_mp(URI.join(url, mp_link.text))
      data.merge! new_data
    end
    # puts data
    ScraperWiki.save_sqlite([:name, :term], data)
  end
end

# scrape_list('http://www.caribbeanelections.com/blog/?p=4101')

scrape_list('http://www.caribbeanelections.com/ag/election2014/candidates/default.asp')
