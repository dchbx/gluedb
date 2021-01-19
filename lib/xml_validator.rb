require 'nokogiri'

class XmlValidator

  attr_accessor :folder_path

  def validate(filename=nil, type: :h36)
    Dir.foreach("#{@folder_path}/transmission") do |filename|
      # Dir.foreach("/Users/raghuram/DCHBX/gluedb/irs/h36_12_14_2015_11_38/transmission") do |filename|
      next if filename == '.' or filename == '..' or filename == 'manifest.xml' or filename == '.DS_Store'

      puts "processing...#{filename.inspect}"

    # H41
    # xsd = Nokogiri::XML::Schema(File.open("#{Rails.root.to_s}/ACA_AIR_5_0_1095A_Schema_Marketplace/MSG/IRS-Form1095ATransmissionUpstreamMessage.xsd")) 

    # doc = Nokogiri::XML(File.open("#{Rails.root.to_s}/irs_h41/FEP0020DC.DSH.EOYIN.D150127.T180947000.P.IN/EOY_Request_00001_20150127T203309Z.xml"))
    # filename = "#{Rails.root.to_s}/HHS_ACA_XML_LIBRARY_8.6_for_Marketplace_Reporting/XML_LIBRARY_8.6/MSG/HHS-IRS-IndividualExchangePeriodicData.xml"
    # xsd = Nokogiri::XML::Schema(File.open("#{Rails.root.to_s}/HHS_ACA_XML_LIBRARY_8.6_for_Marketplace_Reporting/XML_LIBRARY_8.6/MSG/HHS-IRS-MonthlyExchangePeriodicDataMessage-1.0.xsd"))
    # doc = Nokogiri::XML(File.open(filename))
    # xsd.validate(doc).each do |error|
    #   puts error.message
    # end

    # puts "xsd ---- #{Rails.root.to_s}/HHS_ACA_XML_LIBRARY_8.6_for_Marketplace_Reporting/XML_LIBRARY_8.6/MSG/HHS-IRS-MonthlyExchangePeriodicDataMessage-1.0.xsd"
    # xsd = Nokogiri::XML::Schema(File.open("#{Rails.root.to_s}/H36Schema/XML/MSG/HHS-IRS-MonthlyExchangePeriodicDataMessage-1.0.xsd"))

    # xsd = Nokogiri::XML::Schema(File.open("#{Rails.root.to_s}/H36Schema_88/MSG/HHS-IRS-MonthlyExchangePeriodicDataMessage-1.0.xsd"))
    if type == :h41
      xsd = Nokogiri::XML::Schema(File.open("#{Rails.root.to_s}/ACA_AIR5_1095-ASchema-Marketplace/MSG/IRS-Form1095ATransmissionUpstreamMessage.xsd"))
    end
    
    if type == :h36
      xsd = Nokogiri::XML::Schema(File.open("#{Rails.root.to_s}/XML_LIBRARY_8_18/MSG/HHS-IRS-MonthlyExchangePeriodicDataMessage-1.0.xsd")) # IRS 2016
    end

    # xsd = Nokogiri::XML::Schema(File.open("#{Rails.root.to_s}/CMS_XML/XML_LIBRARY_8_18/MSG/SBMPolicyLevelEnrollment-1.0.xsd")) # CMS 2016
    # puts filename.inspect

    doc = Nokogiri::XML(File.open("#{@folder_path}/transmission/" + filename))

    # doc = Nokogiri::XML(File.open("/Users/raghuram/DCHBX/gluedb/irs/h36_12_14_2015_11_38/transmission/" + filename))

    # doc = Nokogiri::XML(File.open(filename))
    # puts "------------------"
    # puts filename.inspect

    xsd.validate(doc).each do |error|
      # puts filename.inspect
      puts error.message
    end
  end
  end
end