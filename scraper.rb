#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

class MembersPage < Scraped::HTML
  decorator Scraped::Response::Decorator::CleanUrls

  field :members do
    noko.css('.views-table tbody tr').map do |tr|
      fragment(tr => MemberRow).to_h
    end
  end
end

class MemberRow < Scraped::HTML
  field :name do
    td[0].at_css('a').text.tidy
  end

  field :party do
    td[1].text.tidy
  end

  field :area do
    td[3].text.tidy
  end

  field :source do
    td[0].at_css('a/@href').text
  end

  private

  def td
    noko.css('td')
  end
end

class MemberPage < Scraped::HTML
  # The IDs before we ported to scraped were all of this form. The site
  # has changed its layout, but for now maintain the same IDs.
  field :id do
    4800000 + url.split('/').last.to_i
  end

  field :name do
    sort_name.split(/\s+,\s+/, 2).reverse.join(' ')
  end

  field :sort_name do
    noko.css('.ficha-legislador h2.pane-title').text.tidy
  end

  field :image do
    pane.css('img[typeof="foaf:Image"]/@src').text.sub(/\?itok.*/, '').tidy
  end

  field :email do
    pane.css('a[href^="mailto:"]').text.tidy
  end

  field :source do
    url
  end

  private

  def pane
    noko.css('.pane-content')
  end
end

def scraper(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

start = 'https://parlamento.gub.uy/sobreelparlamento/integracionhistorica?Cpo_Codigo=D&Quienes=I&Lm_Nombre=0&Tm_Nombre=All'
data = scraper(start => MembersPage).members.map do |mem|
  mem.merge(scraper(mem[:source] => MemberPage).to_h).merge(term: 48)
end
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[id term], data)
