# find_dspace_sites.rb
#
# Uses a variety of sites / registries and some
# tricky XML / HTML parsing (via Nokogiri) to attempt
# to locate DSpace sites out on the web.
#
# Currently searches the following:
#   * OpenDOAR.org
#   * roar.eprints.org
#
# RUN VIA:
#   ruby find_dspace_sites.rb [results-csv-file]
# 
require 'nokogiri'  # Used to parse Google results page
require 'open-uri'  # Used to open Google results page
require 'set'       # Used to filter duplicate URLs
require 'csv'       # Used to write results to CSV
load 'utils.rb'     # Load our utils.rb

##
# Configuration
# Allows you to disable individual search sources
# (Mostly for testing)
##
# Decide which sources to enable for searching
$opendoar = true
$roar = true

# Get output file from commandline arguments
output_file = ARGV.shift

# Query OpenDOAR.org for their list of DSpace sites
# Uses their documented API:
# http://www.opendoar.org/tools/api13manual.html
def opendoar_search()
  results = Array.new

  # If OpenDOAR is disabled in global config, just return no results
  return results if !$opendoar

  puts "---------------------"
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

  # If ROAR is disabled in global config, just return no results
  return results if !$roar

  puts "---------------------"
  puts "Querying ROAR.eprints.org OAI-PMH for set '#{set}'..."

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

# Get an overall results set
overall_results = Array.new

#-----------------
# OpenDOAR search
#-----------------
results = opendoar_search()

# Append to our overall result set
overall_results.push(*results)

#-----------------
# ROAR search
#-----------------
# First, query ROAR for the "DSpace" set
# NOTE: this set ID is from http://roar.eprints.org/cgi/oai2?verb=ListSets
dspace_set = "736F6674776172653D647370616365"
results = roar_search(dspace_set)

# Append to our overall result set
overall_results.push(*results)

# Second, query ROAR for the "Open Repository" set
# NOTE: this set ID is from http://roar.eprints.org/cgi/oai2?verb=ListSets
dspace_set = "736F6674776172653D6F70656E7265706F"
results = roar_search(dspace_set)

# Append to our overall result set
overall_results.push(*results)

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
