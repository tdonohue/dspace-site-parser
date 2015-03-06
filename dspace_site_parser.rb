# dspace_site_parser.rb
# A quick and dirty ruby script to parse DSpace URLs
# and attempt to determine the DSpace version and/or UI
#
# RUN VIA:
# ruby dspace_site_parser.rb [input-csv-file] [results-csv-file]

# REQUIREMENTS:
# gem install nokogiri (may require 'sudo apt get install zlib1g-dev')
#
require 'rubygems'
require 'net/http'  # Used to see if URLs exist (see 'url_response' method)
require 'set'       # Needed for 'url_response' method
require 'nokogiri'  # XML/HTML parser used to determine DSpace version
require 'open-uri'  # Required to pass URLs to nokogiri
require 'csv'       # Used to write results to CSV
load 'utils.rb'     # Load our utils.rb

# Get input & output files from commandline arguments
input_file = ARGV[0]
output_file = ARGV[1]

####################
# Utility methods
####################
# Gets a given URL's response (following any redirects)
# Code tweaked from: http://stackoverflow.com/a/9365490
# AND: http://shadow-file.blogspot.co.uk/2009/03/handling-http-redirection-in-ruby.html
# 
# Parameters:
#    * url = URL to connect to
#    * max_redirects = Max number of redirects to follow (default = 6)
#    * timeout = Response timeout in seconds
# Returns the following:
#   1. Final URL (after following any redirects)
#   2. Response object
#   3. Parsed HTML response (from Nokogiri)
def url_response(url, max_redirects=6, timeout=7)
  response = nil
  parsed_page = nil
  seen = Set.new
  loop do
    url = URI.parse(url)
    break if seen.include? url.to_s
    break if seen.size > max_redirects
    seen.add(url.to_s)
    # initialize our http connection
    http = Net::HTTP.new(url.host, url.port)
    http.open_timeout = timeout
    http.read_timeout = timeout

    # Determine path to access
    # Treat an empty path as "/"
    path = (url.path.nil? or url.path.empty?) ? "/" : url.path
    # Append querystring to path if found
    path = path + "?" + url.query if !url.query.nil?

    # Initialize our HTTP request
    req = Net::HTTP::Get.new(path)

    # Handle HTTPS as needed
    if url.instance_of? URI::HTTPS
       http.use_ssl=true
       http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    # Get back the response (i.e. actually perform request)
    response = http.request(req)
    if response.kind_of?(Net::HTTPRedirection)
      url = response['location']
      parsed_page = nil
    elsif response.kind_of?(Net::HTTPSuccess)
      # Parse the HTML using Nokogiri
      parsed_page = Nokogiri::HTML(response.body)
      # Check for a <meta http-equiv="refresh"> type of redirect
      # If found, we will parse out the redirect URL and load it
      # NOTE: The following is a case insensitive XPATH search for <meta http-equiv="refresh">
      # returning the value of the "content" attribute.
      meta_refresh = parsed_page.xpath("//meta[translate(
                                                @http-equiv, 
                                                'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 
                                                'abcdefghijklmnopqrstuvwxyz'
                                               ) = 'refresh'
                                              ]/@content").to_s
      # Attempt to parse out a URL="" from @content attribute
      if meta_refresh and result = meta_refresh.match(/URL=(.+)/i)
        # Found a redirect URL, we'll load that one next in our loop
        url = result.captures[0].gsub(/['"]/, '')
        parsed_page = nil
      else # Otherwise, we have a valid response & parsed page
        break
      end
    else # Else, response was an error (4xx or 5xx)
      break
    end
  end

  # return final URL response (after redirects)
  # AND the parsed page (from Nokogiri)
  return url, response, parsed_page
end

# Get DSpace information (version, ui-type, etc)
# from a given URL / parsed HTML page. This method
# takes in the output of url_response() and attempts
# to determine if this is a DSpace site or not.
#
# Parameters:
#    * url = URL of the (supposed) DSpace site
#    * parsed_page = HTML Response parsed by Nokogiri
# Returns the following:
#   1. DSpace Version info (or "UNKNOWN")
#   2. DSpace UI type (or "UNKNOWN")
def dspace_info(url, parsed_page)
  #-------------------------
  # Get DSpace Version Info
  #-------------------------
  # Check the parsed page's <meta name="Generator"> tag value)
  # This is the DSpace Version info
  # NOTE: The following is a case insensitive XPATH search for <meta name="generator">
  # returning the value of the "content" attribute.
  generator = parsed_page.xpath("//meta[translate(
                                            @name, 
                                            'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 
                                            'abcdefghijklmnopqrstuvwxyz'
                                        ) = 'generator'
                                       ]/@content").to_s
  # If generator with @content found, then this is the DSpace Version. 
  # Otherwise, version is "UNKNOWN" (or possibly < 1.6.0 when this <meta> tag was added)
  version = (generator and !generator.empty?) ? generator : "UNKNOWN (possibly < 1.6.0)" 
          
  #-------------------------
  # Get DSpace UI Type
  #-------------------------
  
  # Quick check. Does this URL include either "jspui" or "xmlui". 
  # If so, let's trust the URL path is accurate
  if url.to_s.match(/\bjspui\b/i)
    ui_type = "JSPUI"
  elsif url.to_s.match(/\bxmlui\b/i)
    ui_type = "XMLUI"
  end
  
  # If URL match didn't work, we'll have to parse to determine UI type
  if ui_type.nil? or ui_type.empty?
    # To determine XML vs JSPUI we need to send a second request
    # Append "?XML" or "&XML" on original URL path to check if this is XMLUI
    xml_url = url.to_s.include?("?") ? url.to_s + "&XML" : url.to_s + "?XML"
    begin
      xml_url,response,parsed_xml_page = url_response(xml_url)
    rescue => e
      response = nil
      response_error = e
    end
          
    # If second response was successful
    if !response.nil?
      if response.kind_of?(Net::HTTPSuccess)
        # Try to parse this result as XML
        xml = Nokogiri::XML(response.body)
        # If the result is an XML document with a <document> root node,
        # Then this is definitely the XMLUI.
        if xml.root and xml.root.name == "document"
          ui_type = "XMLUI"
        # If our parsed version said this was DSpace, and it is NOT XMLUI, then it must be JSPUI
        elsif(version.include?("DSpace"))
          ui_type = "JSPUI"
        # Else if the response body includes the word "mydspace", this is definitely JSPUI
        elsif(response.body.match(/\bmydspace\b/i))
          ui_type = "JSPUI"
        # Else if the response body includes the word "htmlmap", this is definitely JSPUI
        elsif(response.body.match(/\bhtmlmap\b/i))
          ui_type = "JSPUI"
        # Else if none of the above match, but the response body includes the word "dspace"
        # it's *possibly* JSPUI (but no guarantees)
        elsif(response.body.match(/\bdspace\b/i))
          ui_type = "JSPUI (possibly)"
        else # Otherwise, this really may not be a DSpace UI
          ui_type = "UNKNOWN (may not be DSpace)"
        end
      else # Else if response returned but not a "SUCCESS"
        ui_type = "RESPONSE FAILED: (#{response.code} #{response.message})"
      end
    else # Else if response was nil
      ui_type = "RESPONSE ERROR: (#{response_error})"
    end # End if ?XML response
  end # End if ui_type empty

  # Return parsed DSpace info
  return version, ui_type
end

###########################################
# Actual DSpace URL Processing
# 1. Open up an output CSV
# 2. Open up the input CSV, and parse line-by-line
# 3. Validate DSpace URL & try to determine DSpace version/UI
# 4. Write results to output CSV, line-by-line
###########################################
# Record when we started
beginning_time = Time.now
# Results Counters
count = 0
valid_dspace_count = 0
invalid_url_count = 0
error_count = 0
jspui_count = 0
xmlui_count = 0
unknown_ui_count = 0

# Open our output CSV file for writing (overwrite any existing file)
# Initialize it with a CSV header
CSV.open(output_file, "w",
    :write_headers => true,
    :headers => ["SOURCE", "DSPACE_URL", "RESPONSE", "VERSION_TAG", "UI_TYPE"]) do |csv|

  # Loop through our input CSV line-by-line
  # First line of CSV is assumed to be a header
  # If input CSV has windows encoding, convert to UTF-8. Otherwise UTF-8 is assumed
  CSV.foreach(input_file, :headers => true, :encoding => 'windows-1251:utf-8') do |line|
    count+=1
    # Check number of columns in a line
    if line.length>=2
      source = line[0]
      # Repo URL should be in second column
      url = line[1]
    else
      # If only one column, assume it is Repo URL
      url = line[0]
    end

    # Ensure no nil URLs, and strip whitespace
    url = url.nil? ? "" : url.strip

    puts "-----------------" 
    # Does this look like a valid URI?
    if !url.empty? and uri?(url)
      puts "CHECKING row ##{count}: #{url}"

      #-------------------------
      # Test Repo URL (see if it responds)
      #-------------------------
      # Get URL response (if any)
      begin
        # Load the URL, getting back three return values:
        # 1. a final URL (after redirects)
        # 2. a Response object
        # 3. a Parsed HTML response page (via Nokogiri)
        final_url,response,parsed_page = url_response(url)
      rescue Timeout::Error => e
        response = nil
        response_error = e
        puts "    No response!"
      rescue SocketError => e
        response = nil
        response_error = e
        puts "    SocketError: #{e}"
      rescue => e
        response = nil
        response_error = e
        puts "    Error: #{e}"
      end

      # As long as we have a response
      if !response.nil?
        # Save response details
        response_msg = "#{response.code} #{response.message}"
        puts "    Got response: #{response_msg}"

        # If the URL response was a successful one
        if response.kind_of?(Net::HTTPSuccess)

          # Parse DSpace info about this URL
          version,ui_type = dspace_info(final_url,parsed_page)

          # If UI Type was XMLUI or JSPUI, count this as a "valid" DSpace URL
          if ui_type.include?("XMLUI")
            xmlui_count+=1
            valid_dspace_count+=1
          elsif ui_type.include?("JSPUI")
            jspui_count+=1
            valid_dspace_count+=1
          # Else if UI Type is "UNKNOWN", this may not be a DSpace site
          elsif ui_type.include?("UNKNOWN")
            unknown_ui_count+=1
          else # Otherwise, site parsing resulted in an error of some sort
            error_count+=1
          end

          # Write parsing results to commandline
          puts "    RESULT: DSpace Version=" + version + ", UI=" + ui_type
        else # otherwise, URL returned an error response (4xx or 5xx)
          puts "    RESULT: URL responded with an error (#{response_msg})"
          error_count+=1
        end # if original response success
      # If we had an error returned in the response, 
      elsif response_error
          response_msg = "RESPONSE ERROR: #{response_error}"
          error_count+=1
      else
          response_msg = "RESPONSE TIMEOUT"
          error_count+=1
      end # if response not nil
    else
      puts "Skipping row ##{count}: invalid URL '#{url}'"
      response_msg = "INVALID URL"
      invalid_url_count+=1
    end # if valid url

    #----------------------------
    # Write results to output CSV
    #----------------------------
    # If "final_url" is defined, use it as the output URL
    url = final_url ? final_url.to_s : url
    # Append this URL's results into the output CSV
    csv << [ source, url, response_msg, version, ui_type ]
  end # end loop through input CSV lines (CSV.foreach)
end # end CSV.open

# Output our final results/counts to commandline
processing_time = Time.now - beginning_time
puts "\n##########################\n"
puts " FINAL RESULTS"
puts " PROCESSED #{count} URLs in #{(processing_time / 60).floor} mins, #{(processing_time % 60).floor} secs\n\n"
puts "     Valid DSpace Sites: #{valid_dspace_count} (JSPUI: #{jspui_count} , XMLUI: #{xmlui_count})"
puts "     Unknown User Interface (UI): #{unknown_ui_count}"
puts "     Invalid URLs: #{invalid_url_count}"
puts "     Error / No Response: #{error_count}"
