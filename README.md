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
      
While the command is executing, it will report line-by-line what it is discovering for each DSpace site listed in the `[input-csv-file]`. The official results are also written to the `[output-csv-file]`. 

Once all processing is completed, you will see a summary of the number of sites processed, time it took, and some basic totals, similar to this:

    ##########################
    FINAL RESULTS
    PROCESSED 9 URLs in 0 mins, 15 secs

        Valid DSpace Sites: 5
        Unknown User Interface: 1
        Invalid URLs: 2
        Error / No Response: 1


## Input CSV Format

The input format is assumed to be a (UTF-8 encoded) CSV of this general format:

INFO  | DSPACE_URL
----- | ----------
1  | http://mydspaceurl.com
2  | http://anotherdspaceurl.com:8080
My favorite | http://favoritedspace.edu
Old DSpace | http://doesthiswork.dspace.org

Essentially, it's just a list of DSpace URLs, but the first column can be used to identify them in some way or provide extra info about the URL.
WARNING: if your CSV is NOT UTF-8 encoded (or ASCII, which is a subset of UTF-8), you will likely hit read errors. Make sure to UTF-8 encode it first!

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
* DSPACE_URL = The (possibly updated) DSpace site URL. If the URL from the input CSV was redirected elsewhere, this column will now contain the new, updated URL. Notice in the example above "http://anotherdspaceurl.com:8080" in the input CSV was updated to "http://anotherdspaceurl.com" in the output CSV.
* RESPONSE = The HTTP Response code, or an error message (if response timed out or errored out)
* VERSION_TAG = The parsed DSpace version tag (from `<meta name="generator">`), or "UNKNOWN" if not found
* UI_TYPE = The determined DSpace UI type (XMLUI or JSPUI), or "UNKNOWN" if the UI cannot be determined (or it doesn't look like DSpace)


# Complementary Scripts

## DSpace Locating Scripts

### find_dspace_sites.rb

    ruby find_dspace_sites.rb [results-csv-file]

The `find_dspace_sites.rb` script attempts to locate DSpace Sites in the following sources:
* OpenDOAR.org registry
* ROAR.eprints.org registry
* OpenArchives.org OAI-PMH registry
* U of Illinois OAI-PMH registry

Data from each of those registries is pulled down (via an API or machine readable interface) and parsed for URLs which look like or report to be DSpace sites. The URL list is deduplicated, and written to a CSV which matches the [Input CSV Format](#input-csv-format) of the `dspace_site_parser.rb` script.

### find_dspace_sites_via_google.rb

    ruby find_dspace_sites_via_google.rb [results-csv-file]

The `find_dspace_sites)via_google.rb` script attempts to locate DSpace Sites via a variety of unique Google searches (mostly based on URL paths) which tend to return results that are DSpace URLs.

Data from each of these searches is parsed for URLs which look like or report to be DSpace sites. The URL list is deduplicated, and written to a CSV which matches the [Input CSV Format](#input-csv-format) of the `dspace_site_parser.rb` script.

WARNING: Google obviously does not like or approve of automatically searching and parsing search results. Google will begin throwing 503 errors for every automated query once it realizes that a script is likely running. I do not recommend running this script frequently...it is really just there as an optional way to attempt to locate unregistered DSpace URLs.

## Data Manipulation Scripts

### merge_site_CSVs.rb

    ruby merge_site_CSVs.rb [csv-file-1] [csv-file-2] [merged-csv-file]

This script simply merges two DSpace site CSV files and removes any duplicate entries found. It's useful in merging the outputs of any [DSpace Locating Scripts](#dspace-locating-scripts). Optionally, you can also just pass in a single CSV file to remove its duplicate entries.

By default, the column headers of the *first* CSV are kept in tact, and the second CSV's data is appended onto the end. The input CSVs may be either of the [Input CSV Format](#input-csv-format) or [Output CSV Format](#output-csv-format) detailed above.

### find_country.rb

    ruby find_country.rb [input-csv-file] [csv-file-with-countries]

This script takes in a DSpace site CSV file, and attempts to determine the hosting country of every listed URL. The input CSV file may be either of the [Input CSV Format](#input-csv-format) or [Output CSV Format](#output-csv-format) detailed above.

The result is that the data from the input file is copied to the output CSV, and a new "COUNTRY" column is appended to the end. This new column lists the name of the country, or "UNKNOWN" if unable to be determined.
