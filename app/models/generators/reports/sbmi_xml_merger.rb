require 'nokogiri'

module Generators::Reports  
  class SbmiXmlMerger

    attr_reader :xml_docs
    attr_accessor :sbmi_folder_path, :calender_year, :hios_prefix


    NS = { 
      "xmlns" => "http://sbmi.dsh.cms.gov",
      "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
    }

    def initialize(dir)
      @xml_docs = []
      @doc_count = nil
      @dir = dir
    end

    def process
      # @xml_validator = XmlValidator.new
      # @xml_validator.folder_path = sbmi_folder_path

      read
      merge
    end

    def read
      Dir.glob(@dir+'/*.xml').each do |file_path|
        @xml_docs << Nokogiri::XML(File.open(file_path))
      end

      @doc_count = @xml_docs.count
      @xml_docs
    end

    def build_merged_xml
      consolidated_xml = Nokogiri::XML::Builder.new do |xml|
        xml.Enrollment(NS) do |xml|

          xml.FileInformation do 
            xml.FileId "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}#{hios_prefix}"
            xml.FileCreateDateTime Time.now.utc.iso8601
            xml.TenantId 'DC0'
            xml.CoverageYear calender_year
            xml.IssuerFileInformation do 
              xml.IssuerId hios_prefix
            end
          end
        end
      end

      consolidated_doc = consolidated_xml.doc

      consolidated_doc.xpath('//xmlns:Enrollment', NS).each do |node|
        @xml_docs.each do |xml_doc|
          xml_doc.remove_namespaces!
          new_node = xml_doc.xpath('//Policy').first
          # new_node = chop_special_characters(new_node)
          node.add_child(new_node.to_xml(:indent => 2) + "\n")
        end
      end
    
      consolidated_doc       
    end

    def merge
      file_name = "FEP0020DC.EPS.SBMI.D#{Time.now.utc.strftime('%y%m%d')}.T#{Time.now.utc.strftime('%H%M%S')}000.P.IN"
      @data_file_path = "#{sbmi_folder_path}/#{file_name}"

      File.open(@data_file_path, 'w') do |file|
        file.write build_merged_xml.to_xml(:indent => 2)
      end
    end

    def validate
      puts "processing...#{@data_file_path}"
      xsd = Nokogiri::XML::Schema(File.open("#{Rails.root.to_s}/SBMI.xsd"))
      doc = Nokogiri::XML(File.open(@data_file_path))

      xsd.validate(doc).each do |error|
        puts error.message
      end

      cross_verify_elements
    end

    def cross_verify_elements
      xml_doc = Nokogiri::XML(File.open(@data_file_path))

      element_count = xml_doc.xpath('//xmlns:Policy', NS).count
      if element_count == @doc_count
        puts "Element count looks OK!!"
      else
        puts "ERROR: Processed #{@doc_count} files...but got #{element_count} elements"
      end
    end

    # def self.validate_individuals(dir)
    #   Dir.glob(dir+'/*.xml').each do |file_path|
    #     puts file_path.inspect
    #     @xml_validator.validate(file_path)
    #   end
    # end

    # def chop_special_characters(node)
    #   node.xpath("//SSN", NS).each do |ssn_node|
    #     update_ssn = Maybe.new(ssn_node.content).strip.gsub("-","").value
    #     ssn_node.content = update_ssn
    #   end
      
    #   ["PersonFirstName", "PersonMiddleName", "PersonLastName"].each do |ele|
    #     node.xpath("//#{ele}", NS).each do |xml_tag|
    #       update_ele = Maybe.new(xml_tag.content).strip.gsub(/(\-{2}|\'|\#|\"|\&|\<|\>)/,"").value
    #       if xml_tag.content.match(/(\-{2}|\'|\#|\"|\&|\<|\>)/)
    #         puts xml_tag.content.inspect
    #         puts update_ele
    #       end

    #       if ele == "CityNm"
    #         update_ele = update_ele.gsub(/\s{2}/, ' ')
    #         update_ele = update_ele.gsub(/\-/, ' ')
    #       end

    #       xml_tag.content = update_ele
    #     end
    #   end

    #   # node.xpath("//air5.0:RecordSequenceNum", XMLNS).each do |number|
    #   #   integer_val = Maybe.new(number.content).strip.value.to_i
    #   #   number.content = integer_val
    #   # end

    #   node
    # end
  end
end