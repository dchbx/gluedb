puts 'Loading Brokers'

pattern = File.join(File.dirname(__FILE__), "brokers", "*.xml")

Dir.glob(pattern).each do |file_path|
  file = File.open(file_path, 'r')
  ImportBrokers.from_xml(file)
  file.close
end