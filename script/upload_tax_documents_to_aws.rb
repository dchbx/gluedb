# rails runner script/upload_tax_documents_to_aws.rb '/irs_documents/irs_docs2,/irs_documents/irs_docs3' -e production

folder_paths = ARGV[0]

field_names  = %w(doc_uri uploaded_file_name)

def upload_to_s3(file_name, csv)
  base_name = File.basename(file_name)
  doc_uri = ::Aws::S3Storage.save(file_name, "tax-documents", base_name)
  if doc_uri
    @counter += 1
    csv << [
      doc_uri,
      base_name
    ]
  end
end

file_name = "#{Rails.root}/upload_tax_documents_to_aws_#{Time.now.strftime('%m_%d_%Y_%H_%M_%S')}.csv"

CSV.open(file_name, "w", force_quotes: true) do |csv|
  @counter = 0
  csv << field_names
  folder_paths.split(',').each do |folder_path|
    folder_path = folder_path.strip
    begin
      Dir.entries(folder_path).each do |file_name|
        next if file_name == ('.' || '..')
        file_name = folder_path + file_name.insert(0, '/')
        upload_to_s3(file_name, csv) if File.file?(file_name)
      end
    rescue => e
      unless Rails.env.test?
          puts "Unable to process file or folder, error reason: #{e}"
          puts "Backtrace: #{e.backtrace}"
      end
    end
  end

  puts "Uploaded #{@counter} number of pdfs to S3" unless Rails.env.test?
end
