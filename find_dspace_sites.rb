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
$oai_registry = true

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
# * set_name = Human readable set name
# * set      = the OAI-PMH set identifier
def roar_search(set_name, set)
  results = Array.new

  # If ROAR is disabled in global config, just return no results
  return results if !$roar

  puts "---------------------"
  puts "Querying ROAR.eprints.org OAI-PMH for set \"#{set_name}\"..."

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
      results << [ "roar.eprints.org (Set: #{set_name})", url ]
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

# Query a specified OAI-PMH registry for any registered
# sites that look like a DSpace Site.  DSpace tends to
# have very unique looking OAI-PMH base URLs:
# [dspace-url]/oai/request
#
# Parameters:
# * registry_name = Human readable OAI-PMH registry name
# * xml_interface = the OAI-PMH registries's XML interface
def oai_registry_search(registry_name, xml_interface)
  results = Array.new

  # If OAI Regsitry is disabled in global config, just return no results
  return results if !$oai_registry

  puts "---------------------"
  puts "Querying #{registry_name} OAI-PMH registry for likely DSpace sites ..."
  puts "(using XML interface at: #{xml_interface})"

  # Request the full registry in XML & check return status
  open_page = open(xml_interface)
  puts "       Status returned: #{open_page.status.join(' ')}"

  # Parse the response as XML
  doc = Nokogiri::XML(open_page)
  # Remove namespaces from result, as Nokogiri gets confused by their XML namespaces
  doc.remove_namespaces!

  # In the results, get all <baseURL> tags which contain "/request". 
  # DSpace OAI interfaces tend to look like this [dspace.url]/oai/request
  links = doc.xpath("//baseURL[contains(.,'/request')]")
  # Get size of result set
  puts "       Results found: #{links.length}"

  # Loop through each result
  links.each do |link|
    # Get result URL
    url = link.content.to_s

    # Save URL to our results set, with a source of "OpenDOAR"
    results << [ "#{registry_name} OAI-PMH Registry", url ]
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
results = roar_search("DSpace", dspace_set)

# Append to our overall result set
overall_results.push(*results)

# Second, query ROAR for the "Open Repository" set
# NOTE: this set ID is from http://roar.eprints.org/cgi/oai2?verb=ListSets
dspace_set = "736F6674776172653D6F70656E7265706F"
results = roar_search("Open Repository", dspace_set)

# Append to our overall result set
overall_results.push(*results)

#----------------------------------
# OAI-PMH Registry searches
# Currently, both major OAI-PMH registries
# use a similar XML export format. 
# So we can use the same function!
#----------------------------------

# First, get the results from U of Illinois
results = oai_registry_search("U of Illinois", "http://gita.grainger.uiuc.edu/registry/ListAllRepos.asp?format=xml")

# Second, get the results from OpenArchives.org
results2 = oai_registry_search("OpenArchives.org", "http://www.openarchives.org/pmh/registry/ListFriends")

# Combine the two result sets into one
results.push(*results2)

# Parse these results, discarding anything NOT ending with "/request"
results.keep_if { |source,url| url =~ /\/request$/ }

# Update url set, removing "/[something]oai[something]/request"
# This should result in a likely DSpace homepage URL
results.collect! { |source,url| [source, url.sub(/\/[^\/]*oai[^\/]*\/request$/, '/')] }

# Update url set, removing "/request" (In case previous 'sub' didn't catch everything)
results.collect! { |source,url| [source, url.sub(/\/request$/, '/')] }

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
CSV.open(output_file, "w:UTF-8",
    :write_headers => true,
    :headers => ["SOURCE", "DSPACE_URL"]) do |csv|
  # Loop through results, writing each to CSV
  overall_results.each { |source,url|
    csv << [ source, url ]
  }
end
puts "done."
