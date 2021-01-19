module Generators::Reports::Importers
  class FederalReportIngester

    EOY_DIRECTORY_FILES = "#{Rails.root}/H41_federal_report/EOY_Request*"
    BATCH_PATH = "#{Rails.root}/H41_federal_report/manifest.xml"
    
    def initialize
      @batch_file = File.read(BATCH_PATH)
    end

    def batch_id
      batch_file = Nokogiri::XML(@batch_file)
      batch_id = batch_file.xpath('//ns3:BatchID').text

      return batch_id
    end

    def federal_report_ingester
      Dir[EOY_DIRECTORY_FILES].each do |file_name|
        file_numbers = file_name.scan(/\d+/)
        content_file_number = file_numbers.flatten.detect { |fn| fn.length == 5 }
        file = File.read(file_name)
        doc = Nokogiri::XML(file)
        doc.xpath('//air5.0:Form1095AUpstreamDetail').each do |node|
          record_sequence_number = node.xpath('./air5.0:RecordSequenceNum').text
          federal_policy_id = node.xpath('./air5.0:Policy/air5.0:MarketPlacePolicyNum').text
  
          if record_sequence_number.present? && federal_policy_id.present? && content_file_number.present? && batch_id.present?
            policy = Policy.where(id: federal_policy_id).first
            
            if policy.present?
              fed_trans = policy.federal_transmissions.create!(record_sequence_number: record_sequence_number,
                                                              content_file: content_file_number,
                                                              report_type: indicator,
                                                              batch_id: batch_id
                                                              )
              policy.save!
              if fed_trans.present?
                puts "New federal transmission record created for policy_id:#{federal_policy_id}" unless Rails.env.test?
              else 
                puts "New federal transmission not created for policy_id:#{federal_policy_id}" unless Rails.env.test?
              end
            else
              puts "No policy has been found with this policy_id:#{federal_policy_id}" unless Rails.env.test?
            end
          else
            puts "record_sequence_number: #{record_sequence_number},content_file: #{content_file_number},report_type: #{indicator},
                                                              batch_id: #{batch_id}"
          end
        end
      end
    end

    def indicator
      batch_file = Nokogiri::XML(@batch_file)
      if batch_file.xpath('//ns4:BatchCategoryCode').text == "IRS_EOY_SUBMIT_CORRECTED_RECORDS_REQ"
        "CORRECTED"
      elsif batch_file.xpath('//ns4:BatchCategoryCode').text == "IRS_EOY_SUBMIT_VOID_RECORDS_REQ"
        "VOID"
      else
        "ORIGINAL"
      end  
    end
  end
end
