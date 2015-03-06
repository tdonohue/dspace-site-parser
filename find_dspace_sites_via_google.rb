# find_dspace_sites_via_google.rb
#
# Performs several Google queries to attempt to
# locate DSpace sites out on the web.
#
# Based on the commandline options, you can run
# all queries back to back, or just run individual ones.
# NOTE: If you are too annoying, Google will start throwing 503 errors
# or block you. So, running queries individually is nicer.
#
# RUN VIA:
#   ruby find_dspace_sites_via_google.rb [results-csv-file] [optional-list-of-queries]
#
# For example, this runs just query numbers 1, 2 and 5
#   ruby find_dspace_sites_via_google.rb out.csv 1,2,5
#
require 'nokogiri'  # Used to parse Google results page
require 'open-uri'  # Used to open Google results page
require 'set'       # Used to filter duplicate URLs
require 'csv'       # Used to write results to CSV
load 'utils.rb'     # Load our utils.rb

# Get output file from commandline arguments
output_file = ARGV.shift
$google_search_options = ARGV.shift || "all"

if $google_search_options == "all"
  $google_search_options = ["1","2","3","4","5","6","7","8","9","10"].to_set
else
  $google_search_options = $google_search_options.split(',').to_set
end

# Perform the specified Google search, paging through
# each page of results (up to 1,000 total results)
# NOTE: Google currently limits all searches to 1,000 results
#
# Parameters:
# * query = query to pass to Google
# * pause = amount of time (in seconds) to pause between queries
# * max_results = maximum number of results to return overall (1,000 by default)
# * result_set_size  = number of results to return in one set (100 by default)
#
# Returns a Set of all URLs listed in the Google results
def google_search(query, pause=2, max_results=1000, result_set_size=100)
  start_index = 0
  results = Array.new
 
  # The "Next" link HREF in Google Results
  next_link = ""

  puts "---------------------"
  puts "Performing Google Query: \"#{query}\""

  loop do
    # Exit our loop if we've grabbed the maximum results
    break if start_index >= max_results

    # Build the Google Query String
    # Format: q=[query]&num=[number-of-results]&start=[start-index]
    # NOTE: "filter=0" tells Google not to filter out "similar looking" results and just give us everything
    querystring = URI.encode_www_form("q" => query, "oq" => query, "num" => result_set_size, "start" => start_index, "filter" => "0")

    # If we are past the first page of results, see if we got a "querystring" from the Next button
    if start_index > 0 and !next_link.nil? and !next_link.empty?
      # Get the querystring from our "next_link", by just removing "/search?"
      querystring = next_link.sub(/\/search\?/, '')
      # Clear out the next_link value
      next_link = ""
    end
    puts "... Querying Google with: #{querystring}"
    
    begin
      # Perform Google search, and parse as HTML via Nokogiri
      open_page = open("http://www.google.com/search?#{querystring}")
      puts "       Status returned: #{open_page.status.join(' ')}"
      doc = Nokogiri::HTML(open_page)

      # Parse our Google results page
      # Each result URL is listed in a <cite> tag
      links = doc.xpath('//cite')
      # Get size of result set
      results_found = links.length
      puts "       Results on page: #{results_found}"
      # Loop through each result on page
      links.each do |link|
        # Get result URL, and prepend "http://" if missing
        url = link.content.to_s
        url = url.start_with?("http") ? url : "http://" + url

        # Save URL to our results set, with a source of "Google"
        results << [ "Google '#{query}'", url ]
      end

      # Check for a "Next" link in the Google results
      next_link = doc.xpath('//a[span/text()="Next"]/@href')
      if next_link and !next_link.empty?
        puts "       'Next' link found, requesting next page of results..."
        next_link = next_link.to_s
      else
        puts "       No 'Next' link found. Stopping..."
        break
        # If we found less results than expected, stop processing
        # It's likely there are less than "max_results" for this query
        #break if results_found < result_set_size
        #puts "       No 'Next' Link, but trying one more page of results.."
      end

    rescue OpenURI::HTTPError => e
      puts "       HTTP ERROR response: #{e.message}"
      # Stop processing, we've hit an error
      break
    end

    # Sleep for specified number of seconds before next Google query
    sleep pause+rand(2)

    # Increment our start index to the next set
    start_index += result_set_size
  end # end search loop

  return results
end

# Get an overall results set
overall_results = Array.new

#--------------
# Google search #1 
# Find DSpace sites with "htmlmap" enabled and working
#--------------
if $google_search_options.include?("1")
  results = google_search('htmlmap "url list" -map')

  # Parse these results, discarding anything NOT ending in "/htmlmap"
  results.keep_if { |source,url| url =~ /\/htmlmap$/ }

  # Update url set, removing "htmlmap" from the end of each one
  # This should result in a likely DSpace homepage URL
  results.collect! { |source,url| [source, url.sub(/\/htmlmap/, '/')] }

  # Append to our overall result set
  overall_results.push(*results)
end

#---------------
# Google search #2
# Find DSpace XMLUI's with sitemaps failing
#---------------
if $google_search_options.include?("2")
  results = google_search('htmlmap "ResourceNotFoundException"')

  # Parse these results, discarding anything NOT ending in "/htmlmap"
  results.keep_if { |source,url| url =~ /\/htmlmap$/ }

  # Update url set, removing "htmlmap" from the end of each one
  # This should result in a likely DSpace homepage URL
  results.collect! { |source,url| [source, url.sub(/\/htmlmap/, '/')] }

  # Append to our overall result set
  overall_results.push(*results)
end

#---------------
# Google search #3
# Find sites with /xmlui/community-list in path
#---------------
if $google_search_options.include?("3")
  results = google_search('allinurl:xmlui community-list')

  # Parse these results, discarding anything NOT ending in "/community-list"
  results.keep_if { |source,url| url =~ /\/community-list$/ }

  # Update url set, removing "community-list" from the end of each one
  # This should result in a likely DSpace homepage URL
  results.collect! { |source,url| [source, url.sub(/\/community-list/, '/')] }

  # Append to our overall result set
  overall_results.push(*results)
end
#---------------
# Google search #4:
# Find sites with /jspui/community-list in path
#---------------
if $google_search_options.include?("4")
  results = google_search('allinurl:jspui community-list')

  # Parse these results, discarding anything NOT ending in "/community-list"
  results.keep_if { |source,url| url =~ /\/community-list$/ }

  # Update url set, removing "community-list" from the end of each one
  # This should result in a likely DSpace homepage URL
  results.collect! { |source,url| [source, url.sub(/\/community-list/, '/')] }

  # Append to our overall result set
  overall_results.push(*results)
end

#---------------
# Google search #5
# Find sites with community-list and dspace in path
#---------------
if $google_search_options.include?("5")
  results = google_search('allinurl:dspace community-list')

  # Parse these results, discarding anything NOT ending in "/community-list"
  results.keep_if { |source,url| url =~ /\/community-list$/ }

  # Update url set, removing "community-list" from the end of each one
  # This should result in a likely DSpace homepage URL
  results.collect! { |source,url| [source, url.sub(/\/community-list/, '/')] }

  # Append to our overall result set
  overall_results.push(*results)
end

#---------------
# Google search #6
# Find sites with oai and request in path
#---------------
if $google_search_options.include?("6")
  results = google_search('allinurl:oai request')

  # Parse these results, discarding anything NOT including "oai/request"
  results.keep_if { |source,url| url =~ /oai\/request/ }

  # Update url set, removing "/[something]oai/request"
  # (and optionally a querystring)
  # This should result in a likely DSpace homepage URL
  results.collect! { |source,url| [source, url.sub(/\/[^\/]*oai\/request(\?.*)?$/, '/')] }

  # Append to our overall result set
  overall_results.push(*results)
end

#----------------
# Remove all duplicate results from our result set
#----------------
puts "---------------------"
puts "Removing invalid URLs..."
overall_results.keep_if { |source,url| uri?(url) }
puts "done."
puts "Removing duplicate URLs..."
overall_results.uniq! { |source,url|
  # Parse the URL, returning a "comparable" version
  # which can be used to determine uniqueness
  comparable_uri(url)
}
puts "done."

#----------------
# Export all results to a two column CSV file
# NOTE: the first column is the "Source" of the DSpace URL
# (i.e where we found it)
puts "Writing results to CSV..."
CSV.open(output_file, "w",
    :write_headers => true,
    :headers => ["SOURCE", "DSPACE_URL"]) do |csv|
  # Loop through results, writing each to CSV
  overall_results.each { |source,url|
    csv << [ source, url ]
  }
end
puts "done."
