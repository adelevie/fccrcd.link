require 'bundler/setup'
require 'sinatra/base'
require 'sinatra/respond_with'
require 'pry'
require 'nokogiri'
require 'json'
require 'mongoid'
require 'uri'
require 'net/http'
require 'dotenv'
Dotenv.load

Mongoid.load!('mongoid.yml')

class Citation
  include Mongoid::Document
end

def get_or_create_citation(volume: nil, page: nil)
  # Example citation: 22 FCC Rcd 17791
  citation = Citation.where(volume: volume, page: page)
  
  if citation
    return citation
  else
    return Citation.create(get_citation(volume: volume, page: page))
  end
end

def get_citation(volume: nil, page: nil)
  base_url = 'https://apps.fcc.gov/edocs_public/'
  url = base_url + 'Query.do?mode=advance&rpt=cond'
  params = {
    'fccRecordVol' => volume,
    'fccRecordPage' => page
  }
  resp = Net::HTTP.post_form(URI.parse(url), params)
  html = resp.body
  doc  = Nokogiri::HTML(html)

  css = "table.tableWithBorder"
  table = doc.search(css)

  links = table.search('a')
  links.shift
  urls = links.map do |link|
    base_url + link.attributes['href'].value rescue nil
  end.reject(&:nil?)
  
  rows = table.search('tr')

  title = rows[0].text.strip
  date = rows[1].text.strip
  description = rows[2].text.strip

  hash = {
    volume: volume,
    page: page,
    title: title,
    date: date,
    description: description,
    pdf: [],
    doc: [],
    txt: []
  }

  urls.each do |url|
    if url.end_with?('pdf')
      hash[:pdf] << url
    end
    if url.end_with?('txt')
      hash[:txt] << url
    end
    if url.end_with?('doc')
      hash[:doc] << url
    end
  end
  
  return hash
end

class App < Sinatra::Base
  register Sinatra::RespondWith
  
  get '/' do
    erb :index
  end
  
  get '/:volume/:page' do
    citation = get_citation(volume: params[:volume], page: params[:page])
    
    respond_to do |f|
      f.json do
        JSON.generate citation
      end
      f.html do
        erb :citation, locals: {citation: citation}
      end
    end    
  end

end
