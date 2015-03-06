# util.rb
# Various utility methods useful in parsing URLs, etc
#
# Include via:
#   load 'util.rb'
require 'open-uri'

# Check if a string is a valid URL
# Returns true/false based on whether URL is valid
# Borrowed from: http://stackoverflow.com/a/5331096
def uri?(string)
  uri = URI.parse(string)
  %w( http https ).include?(uri.scheme)
rescue URI::BadURIError
  false
rescue URI::InvalidURIError
  false
end


# Parses a given string as a URI and
# returns the "host/path" string, which
# can be used to compare one web address
# to another to determine uniqueness of a URI
def comparable_uri(string)
  if uri?(string)
    uri = URI.parse(string)
    # Strip any "www." from host
    host = uri.host.sub(/www\./,'')
    # Treat an empty path as "/"
    path = (uri.path.nil? or uri.path.empty?) ? "/" : uri.path
    # If path doesn't end with a slash, add it
    path = path.end_with?("/") ? path : path + "/"
    # Return [host]/[path]
    host + path
  else
    # If not a URI, just return empty string
    # We don't want to compare or keep around non-URIs
    ""
  end
end
