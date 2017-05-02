#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(url)
  noko = noko_for(url)
  current_party = nil
  noko.xpath('//table[contains(.,"TITULARES")]//tr[td]').each do |tr|
    if tr.xpath('.//td[@colspan=9 and contains(.,"PARTIDO")]').any?
      current_party = tr.text.tidy
      next
    end
    next unless current_party

    tr.css('td').each_slice(3).each do |tds|
      next unless tds.count == 3
      link = URI.join(url, tds[2].css('li a[title*="Sitio Personal"]/@href').text).to_s

      data = {
        id:     link[/ID=(\d+)/, 1],
        name:   tds[2].css('strong').text.tidy,
        party:  current_party,
        area:   tds[2].xpath('.//font/text()').first.text.sub('Departamento de ', '').tidy,
        image:  tds[0].css('img/@src').text,
        email:  tds[2].css('li a[href*="mailto:"]/@href').text.sub('mailto:', ''),
        term:   48,
        source: link,
      }
      data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?
      ScraperWiki.save_sqlite(%i(id term), data)
    end
  end
end

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
scrape_list('https://www.parlamento.gub.uy/palacio3/legisladores/conozcaasuslegisladores.asp?Cuerpo=D&Legislatura=48&Tipo=T')
