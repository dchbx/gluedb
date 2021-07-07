require 'yaml'
require 'active_support/core_ext/array/wrap'

def whitelist
  @whitelist ||= YAML.load_file('.whitelisted_ssn_occurances.yml')
end

def whitelisted?(file, line)
  file_match = whitelist.detect do |item|
    item['file'] == file
  end
  return false unless file_match

  line_match = Array.wrap(file_match['exceptions']).detect do |exception|
    exception == line
  end

  return false unless line_match
  true
end

matched_ssns = []

files = `git diff --cached --name-status | awk '$1 != "D" { print $2 }'`
files.split("\n").each do |file|
  File.readlines(file).each_with_index do |line, n|
    line.chomp!
    if line =~ /\d{3}-?\d{2}-?\d{4}/ && !whitelisted?(file, line)
      puts "Found possible SSN on line #{n} in #{file}, line is: #{line}"
      matched_ssns.push([file, line, n])
    end
  end
end

exit matched_ssns.empty?
