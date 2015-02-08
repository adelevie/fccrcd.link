require 'bundler/setup'
require 'sinatra/base'
require 'pry'
require 'nokogiri'
require 'json'

# Example citation: 22 FCC Rcd 17791

require 'uri'
require 'net/http'

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

  links = doc.search(css).search('a')
  links.shift
  urls = links.map do |link|
    base_url + link.attributes['href'].value rescue nil
  end.reject(&:nil?)

  hash = {
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
  get '/:volume/:page' do
    content_type :json
    resp = get_citation(volume: params[:volume], page: params[:page])
    return JSON.generate(resp)
  end
end
