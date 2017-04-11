require 'scraperwiki'
require 'rubygems'
require 'date'
require 'net/https'
require 'json'
require 'open-uri'
require "mechanize"

@agent = Mechanize.new

# Get the list of venues from the venue scraper
url = "http://www.ncat.nsw.gov.au/Pages/going_to_the_tribunal/hearing_lists.aspx"
page = @agent.get(url)
table = page.at("table.ms-rteTable-4")
venue_links = table.search(:td).collect { |td| td.search(:a) }.flatten
venue_list = venue_links.collect { |a| {url: a.attr(:href), location: a.attr(:title), postcode: a.attr(:href)[/(\d{4}$)/]} }

venue_list.each do |v|
  page = @agent.get(v[:url])

  # This way of working out the dates probably won't last
  # need to work out when the data is posted, etc.
  (Date.today..Date.today + 30).each do |d|
    puts "Processing #{d} for #{v[:postcode]}"
    id = '//*[@id="dg' + d.strftime("%-d%-m%Y") + '"]'
    (page/id).each do |r|
      # First get room and time. The format is different for the first
      # result
      if r.previous.previous.search('b')[1].nil?
        time_and_place = r.previous.previous.inner_text
      else
        time_and_place = r.previous.previous.search('span').last.inner_text
      end

      # Now the cases
      r.search('tr.clsGridItem').each do |c|
        cttt_case = {
          'unique_id'           => (d.to_s + c.search('td')[0].inner_text).split.join,
          'case_number'         => c.search('td')[0].inner_text,
          'party_a'             => c.search('td')[1].inner_text,
          'party_b'             => c.search('td')[2].inner_text,
          'date'                => d.to_s,
          'time'                => time_and_place.split(" at ", 2)[0],
          'location'            => time_and_place.split(" at ", 2)[1].strip,
          'venue'               => v[:location],
          'venue_postcode'      => v[:postcode]
        }

        ScraperWiki.save(['unique_id'], cttt_case)
      end
    end
  end
end
