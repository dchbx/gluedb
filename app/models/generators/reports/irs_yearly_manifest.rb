module Generators::Reports  
  class IrsYearlyManifest

    attr_accessor :notice_params, :policy, :most_recent_original_transmission

    NS = {
      "xmlns"  => "http://birsrep.dsh.cms.gov/exchange/1.0",
      "xmlns:ns3"  => "http://hix.cms.gov/0.1/hix-core", 
      "xmlns:ns4"  => "http://birsrep.dsh.cms.gov/extension/1.0",
      "xmlns:ns5"  => "http://niem.gov/niem/niem-core/2.0"
      # "xmlns:inp1" => "http://xmlns.oracle.com/singleString", 
      # "xmlns:wsa"  => "http://www.w3.org/2005/08/addressing"      
    }

    def create(folder, notice_params = nil)
      @folder = folder
      @notice_params = notice_params
      @policy = Policy.find(notice_params[:policy_id])
      @most_recent_original_transmission = policy.federal_transmissions.where(report_type: 'ORIGINAL').last
      @manifest = OpenStruct.new({
        file_count: Dir.glob(@folder+'/*.xml').count,
      })
      manifest_xml = serialize.to_xml(:indent => 2)
      File.open("#{folder}/manifest.xml", 'w') do |file|
        file.write manifest_xml
      end
    end

    def serialize
      Nokogiri::XML::Builder.new { |xml|
        xml['ns5'].BatchHandlingServiceRequest(NS) do |xml|
          serialize_batch_data(xml)
          serialize_transmission_data(xml)
          serialize_service_data(xml)
          attachments.each do |attachment|
            serialize_attachment(xml, attachment)
          end
        end
      }
    end

    def attachments
      Dir.glob(@folder+'/*.xml').inject([]) do |data, file|
        data << OpenStruct.new({
          checksum: Digest::SHA256.file(file).hexdigest,
          binarysize: File.size(file),
          filename: File.basename(file),
          sequence_id: File.basename(file).match(/\d{5}/)[0] # Has only 5 digits total
        })
      end
    end

    def serialize_batch_data(xml)
      type = notice_params[:type]
      xml['ns3'].BatchMetadata do |xml|
        xml.BatchID Time.now.utc.iso8601
        xml.BatchPartnerID '02.DC*.SBE.001.001'
        xml.BatchAttachmentTotalQuantity @manifest.file_count
        # This are lowercase strings in irs_yearly_serializer
        if type.match(/corrected/i)
          xml['ns4'].BatchCategoryCode 'IRS_EOY_SUBMIT_CORRECTED_RECORDS_REQ'
          xml.BatchTransmissionQuantity 1
        elsif type.match(/void/i)
          xml['ns4'].BatchCategoryCode 'IRS_EOY_SUBMIT_VOID_RECORDS_REQ'
          xml.BatchTransmissionQuantity 1
        else # original/new
          xml['ns4'].BatchCategoryCode 'IRS_EOY_REQ'
          xml.BatchTransmissionQuantity 1
        end
      end
    end

    def serialize_transmission_data(xml)
      xml['ns3'].TransmissionMetadata do |xml|
        xml.TransmissionAttachmentQuantity @manifest.file_count
        xml.TransmissionSequenceID 1
      end
    end

    def serialize_service_data(xml)
      xml['ns4'].ServiceSpecificData do |xml|
        xml.ReportPeriod do |xml|
          xml['ns5'].Year notice_params[:calender_year]
        end
        xml['ns4'].OriginalBatchID most_recent_original_transmission.batch_id.to_s
      end
    end

    def serialize_attachment(xml, file)
      xml['ns4'].Attachment do |xml|
        xml['ns5'].DocumentBinary do |xml|
          xml['ns3'].ChecksumAugmentation do |xml|
            xml['ns4'].SHA256HashValueText file.checksum
          end
          xml['ns3'].BinarySizeValue file.binarysize
        end
        xml['ns5'].DocumentFileName file.filename
        xml['ns5'].DocumentSequenceID file.sequence_id
      end
    end
  end
end
