# find_dspace_sites.rb
#
# Uses a variety of sites / search engines and some
# tricky XML / HTML parsing (via Nokogiri) to attempt
# to locate DSpace sites out on the web.
#
# Currently searches the following:
#   * OpenDOAR.org
#   * roar.eprints.org
#   * Google (with various DSpace specific searches)
#
# RUN VIA:
#   ruby find_dspace_sites.rb [results-csv-file]
# 
require 'nokogiri'  # Used to parse Google results page
require 'open-uri'  # Used to open Google results page
require 'set'       # Used to filter duplicate URLs
require 'csv'       # Used to write results to CSV
load 'utils.rb'     # Load our utils.rb

# Get output file from commandline arguments
output_file = ARGV[0]

# Query OpenDOAR.org for their list of DSpace sites
# Uses their documented API:
# http://www.opendoar.org/tools/api13manual.html
def opendoar_search()
  results = Array.new

  puts "Querying OpenDOAR.org for Keyword='DSpace' ..."
  
  # Perform the query using OpenDOAR API (kwd=dspace) & check return status
  open_page = open("http://www.opendoar.org/api.php?kwd=dspace")
  puts "       Status returned: #{open_page.status.join(' ')}"

  # Parse the response as XML
  doc = Nokogiri::XML(open_page)
  # In the results, get all <rUrl> tags. Those are the Repository URLs
  links = doc.xpath('//rUrl')
  # Get size of result set
  puts "       Results found: #{links.length}"

  # Loop through each result
  links.each do |link|
    # Get result URL
    url = link.content.to_s

    # Save URL to our results set, with a source of "OpenDOAR"
    results << [ "OpenDOAR.org", url ]
  end

  return results
end 


# Get the specified "Set" from the http://roar.eprints.org/ OAI-PMH interface.
# Since ROAR doesn't have an API, we just query its OAI-PMH interface for
# set(s) related to DSpace.
# To locate a set identifier just visit:
# http://roar.eprints.org/cgi/oai2?verb=ListSets
#
# Parameters:
# * set = the OAI-PMH set identifier
def roar_search(set)
  results = Array.new

  puts "Querying ROAR.eprints.org OAI-PMH for set 'DSpace'..."

  # Build initial OAI-PMH querystring
  querystring = URI.encode_www_form("verb" => "ListRecords", "metadataPrefix" => "oai_dc", "set" => set)

  loop do
    puts "... Querying OAI-PMH with: #{querystring}"

    # Perform the query using OAI-PMH & check return status
    open_page = open("http://roar.eprints.org/cgi/oai2?#{querystring}")
    puts "       Status returned: #{open_page.status.join(' ')}"

    # Parse the response as XML
    doc = Nokogiri::XML(open_page)
    # Remove namespaces from result, Nokogiri gets confused by OAI-PMH namespaces
    doc.remove_namespaces!
    
    # In the results, get all <identifier> metadata tags. Those are the Repository URLs
    links = doc.xpath('//metadata/dc/identifier')
    # Get size of result set
    puts "       Results found: #{links.length}"

    # Loop through each result
    links.each do |link|
      # Get result URL
      url = link.content.to_s

      # Save URL to our results set, with a source of "ROAR"
      results << [ "roar.eprints.org", url ]
    end

    # Parse out the OAI-PMH ResumptionToken (for the next page of results)
    resumptionToken = doc.xpath('//resumptionToken')
    # If ResumptionToken found, use it as the next querystring
    if resumptionToken and !resumptionToken.empty?
      querystring = "verb=ListRecords&resumptionToken=" + resumptionToken.first.content.to_s
    # Otherwise, exit our loop. We have all the results
    else
      break
    end
  end

  return results
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

  puts "Performing Google Query: #{query}"

  loop do
    # Exit our loop if we've grabbed the maximum results
    break if start_index >= max_results

    # Build the Google Query String
    # Format: q=[query]&num=[number-of-results]&start=[start-index]
    # NOTE: "filter=0" tells Google not to filter out "similar looking" results and just give us everything
    querystring = URI.encode_www_form("q" => query, "num" => result_set_size, "start" => start_index, "filter" => "0")
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

      # If we found less results than expected, stop processing
      # It's likely there are less than "max_results" for this query
      break if results_found < result_set_size
    rescue OpenURI::HTTPError => e
      puts "       HTTP ERROR response: #{e.message}"
      # Stop processing, we've hit an error
      break
    end

    # Sleep for specified number of seconds before next Google query
    sleep pause

    # Increment our start index to the next set
    start_index += result_set_size
  end # end search loop

  return results
end

# Get an overall results set
overall_results = Array.new

# @TODO
# ROAR - via OAI-PMH
#   Has a separate "DSpace" set and an "Open Repository" set, etc.
#   http://roar.eprints.org/cgi/oai2?verb=ListSets
#   DSpace set: http://roar.eprints.org/cgi/oai2?verb=ListRecords&metadataPrefix=oai_dc&set=736F6674776172653D647370616365
# OPENDOAR - via API
#   http://www.opendoar.org/tools/api13manual.html
puts "---------------------"

#-----------------
# OpenDOAR search
#-----------------
results = opendoar_search()

# Append to our overall result set
overall_results.push(*results)
puts "---------------------"

#-----------------
# ROAR search
#-----------------
# First, query ROAR for the "DSpace" set
# NOTE: this set ID is from http://roar.eprints.org/cgi/oai2?verb=ListSets
dspace_set = "736F6674776172653D647370616365"
results = roar_search(dspace_set)

# Append to our overall result set
overall_results.push(*results)
puts "---------------------"

# Second, query ROAR for the "Open Repository" set
# NOTE: this set ID is from http://roar.eprints.org/cgi/oai2?verb=ListSets
dspace_set = "736F6674776172653D6F70656E7265706F"
results = roar_search(dspace_set)

# Append to our overall result set
overall_results.push(*results)
puts "---------------------"

#--------------
# Google search: 
# Find DSpace sites with "htmlmap" enabled and working
#--------------
results = google_search('htmlmap "url list" -map')

# Parse these results, discarding anything NOT ending in "/htmlmap"
results.keep_if { |source,url| url =~ /\/htmlmap$/ }

# Update url set, removing "htmlmap" from the end of each one
# This should result in a likely DSpace homepage URL
results.collect! { |source,url| [source, url.sub(/\/htmlmap/, '/')] }

# Append to our overall result set
overall_results.push(*results)
puts "---------------------"

#---------------
# Google search:
# Find DSpace XMLUI's with sitemaps failing
#---------------
results = google_search('htmlmap "ResourceNotFoundException"')

# Parse these results, discarding anything NOT ending in "/htmlmap"
results.keep_if { |source,url| url =~ /\/htmlmap$/ }

# Update url set, removing "htmlmap" from the end of each one
# This should result in a likely DSpace homepage URL
results.collect! { |source,url| [source, url.sub(/\/htmlmap/, '/')] }

# Append to our overall result set
overall_results.push(*results)
puts "---------------------"

#---------------
# Google search:
# Find sites with /xmlui/community-list in path
#---------------
results = google_search('allinurl:xmlui community-list')

# Parse these results, discarding anything NOT ending in "/community-list"
results.keep_if { |source,url| url =~ /\/community-list$/ }

# Update url set, removing "community-list" from the end of each one
# This should result in a likely DSpace homepage URL
results.collect! { |source,url| [source, url.sub(/\/community-list/, '/')] }

# Append to our overall result set
overall_results.push(*results)
puts "---------------------"

#---------------
# Google search:
# Find sites with /jspui/community-list in path
#---------------
results = google_search('allinurl:jspui community-list')

# Parse these results, discarding anything NOT ending in "/community-list"
results.keep_if { |source,url| url =~ /\/community-list$/ }

# Update url set, removing "community-list" from the end of each one
# This should result in a likely DSpace homepage URL
results.collect! { |source,url| [source, url.sub(/\/community-list/, '/')] }

# Append to our overall result set
overall_results.push(*results)
puts "---------------------"

#---------------
# Google search:
# Find sites with community-list and dspace in path
#---------------
results = google_search('allinurl:dspace community-list')

# Parse these results, discarding anything NOT ending in "/community-list"
results.keep_if { |source,url| url =~ /\/community-list$/ }

# Update url set, removing "community-list" from the end of each one
# This should result in a likely DSpace homepage URL
results.collect! { |source,url| [source, url.sub(/\/community-list/, '/')] }

# Append to our overall result set
overall_results.push(*results)
puts "---------------------"


#----------------
# Remove all duplicate results from our result set
#----------------
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
