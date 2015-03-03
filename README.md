# dspace-site-parser
A simple Ruby CLI script to parse a list of DSpace sites for basic info (version, UI of choice, etc)

## Prerequisites
* Ruby 
* RubyGems
* [Nokogiri](http://www.nokogiri.org/) gem
    * sudo apt get install zlib1g-dev (required for 'nokogiri') 
    * gem install nokogiri

## How to Run

      ruby dspace_site_parser.rb [input-csv-file] [output-csv-file]
      
## Input CSV Format

The input format is assumed to be a CSV of this general format:

ID / Info  | DSpace URL
------------- | -------------
1  | http://mydspaceurl.com
2  | http://anotherdspaceurl.com:8080
My favorite | http://favoritedspace.edu
Old DSpace | http://doesthiswork.dspace.org

Essentially, it's just a list of DSpace URLs, but the first column can be used to identify them in some way or provide extra info about the URL.

## Output CSV Format

The output CSV format is as follows

INFO  | DSPACE_URL | RESPONSE | VERSION_TAG | UI_TYPE
----- | ---------- | -------- | ----------- | ------ 
1     | http://mydspaceurl.edu/xmlui | 200 OK | UNKNOWN | XMLUI
2     | http://anotherdspaceurl.com | 200 OK | DSpace 4.2 | JSPUI
My favorite | http://favoritedspace.edu | 200 OK | DSpace 5.1 | XMLUI
Old DSpace | http://doesthiswork.dspace.org | 404 Not Found | | |

Column explanations:

* INFO Column = Just a copy of what was in the input CSV. This is used to identify the URL between the input and output
* DSPACE_URL = The (possibly updated) DSpace site URL. If the URL from the input CSV was redirected elsewhere, this column will not contain the NEW URL location.
* RESPONSE = The HTTP Response code, or an error message (if response timed out or errored out)
* VERSION_TAG = The parsed DSpace version tag (from `<meta name="generator">`), or "UNKNOWN" if not found
* UI_TYPE = The determined DSpace UI type (XMLUI or JSPUI), or "UNKNOWN" if the UI cannot be determined (or it doesn't look like DSpace)
