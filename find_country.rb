# encoding: UTF-8

# find_country.rb
#
# Takes in a DSpace site CSV and attempts to lookup
# the country information for each site listed.
# Outputs the same CSV with a "COUNTRY" column appended.
#
# RUN VIA:
#   ruby find_country.rb [csv-file] [output-csv-file] 
#
# 
require 'csv'
require 'net/http'
require 'nokogiri'
load 'utils.rb'     # Load our utils.rb

# Get commandline arguments
input_csv = ARGV.shift
output_csv = ARGV.shift
# Default URL column to index 1, unless specified
url_column_index = ARGV.shift || 1

puts "Reading CSV and appending country info.."
# Open a new (temporary) merged CSV
CSV.open(output_csv, 'w:UTF-8') do |csv|

  count = 0

  # Read all the entries from the first CSV
  # and write them to the merged CSV
  # (Leave headers in place)
  CSV.foreach(input_csv, :encoding => 'utf-8') do |row|
    count+=1

    # Get our URL column
    url = row[url_column_index]
    # Ensure no nil URLs, and strip whitespace
    url = url.nil? ? "" : url.strip

    # Does this look like a valid URI?
    if !url.empty? and uri?(url)
      puts "Looking up row ##{count}: #{url}"  
      
      # Parse our URL
      url = URI.parse(url)

      begin
        # Lookup location via http://freegeoip.net/
        open_page = open("http://freegeoip.net/xml/#{url.host}")

        puts "  Status returned: #{open_page.status.join(' ')}"
        # Parse the response as XML
        doc = Nokogiri::XML(open_page)
        # Get the CountryCode
        result = doc.xpath('//CountryName/text()')
        country = result and !result.empty? ? result.first.content.to_s : "UNKNOWN"
      rescue
        country = "UNKNOWN"  
      end
    end

    puts "  Country: #{country}"
    
    if count==1
      csv << (row << "COUNTRY")
    else
      csv << (row << country )
    end
  end  
end
puts "done."
