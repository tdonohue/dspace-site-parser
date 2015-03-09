# encoding: UTF-8

# merge_site_csvs.rb
#
# Merges two DSpace site CSVs into a single output
# CSV, removing duplicate entries. Also can be used
# to just remove duplicate entries from one CSV.
# 
# Duplicates are determined by the URL column (index: 1 by default)
#
# RUN VIA:
#   ruby merge_site_csvs.rb [first-csv-file] [second-csv-file] [merged-csv-file] 
#
# * If only one CSV is specified, it will just be deduplicated and written to "output.csv"
# * If two CSVs are specified, they will be merged and deduplicated and written to "output.csv"
# 
require 'csv'       # Used to merge CSV
load 'utils.rb'     # Load our utils.rb

# Get commandline arguments
first_csv = ARGV.shift
second_csv = ARGV.shift
# If merged CSV unspecified, default to "output.csv"
merged_csv = ARGV.shift || "output.csv"
# Default URL column to index 1, unless specified
url_column_index = ARGV.shift || 1

temp_csv = merged_csv + ".temp"

puts "Merging CSVs..."
# Open a new (temporary) merged CSV
CSV.open(temp_csv, 'w:UTF-8') do |csv|

  # Read all the entries from the first CSV
  # and write them to the merged CSV
  # (Leave headers in place)
  CSV.foreach(first_csv, :encoding => 'windows-1251:utf-8') do |row|
    csv << row
  end
  
  # Read all the entries from the second CSV
  # and write them to the merged CSV
  if second_csv
    CSV.foreach(second_csv, :headers => true, :encoding => 'windows-1251:utf-8') do |row|
      csv << row
    end
  end
end
puts "done."

puts "Removing duplicate entries based on URL column index #{url_column_index}..."
# Now, remove all duplicates from our merged CSV
CSV.open(merged_csv, 'w:UTF-8') do |csv|  
  # Read all it's current entries, and remove duplicates
  CSV.read(temp_csv, :encoding => 'utf-8').uniq{|x|
                           # Parse the URL, returning a "comparable" version
                           # which can be used to determine uniqueness
                           comparable_uri(x[url_column_index])
                         }.each do |row|
    csv << row
  end
end
puts "done."

# Delete the temp file
File.delete(temp_csv)
