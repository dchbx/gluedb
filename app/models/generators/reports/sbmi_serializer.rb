require 'spreadsheet'
require 'csv'
module Generators::Reports  
  class SbmiSerializer

    CALENDER_YEAR = 2019
    # CANCELED_DATE = Date.new(2017,12,8)

    attr_accessor :pbp_final

    def initialize
      @sbmi_root_folder = "#{Rails.root}/sbmi"
      # @sbmi_folder_name = "DCHBX_SBMI_78079_17_00_01_06_2017"
      # hios_prefix = "78079"
      # CALENDER_YEAR = 2017

      create_directory @sbmi_root_folder
    end

    def process
      # %w(86052 78079 94506).each do |hios_prefix|
      # %w(86052).each do |hios_prefix|

      %w(86052 78079 94506 81334 92479 95051).each do |hios_prefix|
# %w(86052).each do |hios_prefix|
        plan_ids = Plan.where(hios_plan_id: /^#{hios_prefix}/, year: CALENDER_YEAR).pluck(:_id)
        puts "Processing #{hios_prefix}"

        # workbook = Spreadsheet::Workbook.new
        # sheet = workbook.create_worksheet :name => "#{CALENDER_YEAR} SBMI Report"

        # index = 0
        # sheet.row(index).concat headers

        create_sbmi_folder(hios_prefix)

        count = 0
        Policy.where(:plan_id.in => plan_ids).each do |pol|

        # Policy.where(:id.in => %w(182528)).each do |pol|
          next if pol.is_shop? || pol.rejected? # || pol.has_responsible_person?

          # * re-enable for post first report in a calender year
          # if pol.canceled?
          #   next if pol.updated_at < Date.new(CALENDER_YEAR,5,1)
          # else
          #   next if pol.has_no_enrollees?
          # end

          # disbale for post first report in a calender year
          # next if pol.canceled? && pol.updated_at < CANCELED_DATE

          # next if pol.canceled?
          # next if pol.has_no_enrollees?
          next if pol.policy_start < Date.new(CALENDER_YEAR, 1, 1)
          next if pol.policy_start > Date.new(CALENDER_YEAR, 12, 31)
          if pol.subscriber.person.blank?
            puts "subscriber person record missing #{pol.id}"
            next
          end
          next if !pol.belong_to_authority_member?
          next if policies_to_skip.include?(pol.id.to_s)
          next if pol.kind == 'coverall'
          count +=1 
          if count % 100 == 0
            puts "processing #{count}"
          end
          
          begin
            builder = Generators::Reports::SbmiPolicyBuilder.new(pol)
            builder.process
          rescue Exception => e
            puts "Exception: #{pol.id}"
            puts e.inspect
            next
          end

          sbmi_xml = SbmiXml.new
          sbmi_xml.sbmi_policy = builder.sbmi_policy
          sbmi_xml.folder_path = "#{@sbmi_root_folder}/#{@sbmi_folder_name}"
          sbmi_xml.serialize

          # index += 1
          # sheet.row(index).concat builder.sbmi_policy.to_csv
        end

        merge_and_validate_xmls(hios_prefix)

        # workbook.write "#{Rails.root.to_s}/#{CALENDER_YEAR}_SBMI_DATA_EXPORT_#{Time.now.strftime("%Y_%m_%d_%H_%M")}_#{hios_prefix}.xls"
      end
    end

     def merge_and_validate_xmls(hios_prefix)
      xml_merge = Generators::Reports::SbmiXmlMerger.new("#{@sbmi_root_folder}/#{@sbmi_folder_name}")
      xml_merge.sbmi_folder_path = @sbmi_root_folder
      xml_merge.hios_prefix = hios_prefix
      xml_merge.calender_year = CALENDER_YEAR
      xml_merge.process
      xml_merge.validate
    end

    # def self.generate_sbmi(listener, coverage_year, pbp_final)
    #   CALENDER_YEAR = coverage_year.to_i

    #   begin
    #     set_cancel_date
    #     binding.pry
    #     sbmi_serializer = Generators::Reports::SbmiSerializer.new
    #     sbmi_serializer.pbp_final = pbp_final
    #     sbmi_serializer.process
    #     return "200"
    #   rescue Exception => e
    #     return "500"
    #   end
    # end

    # def set_cancel_date
    #   prev_month = Date.today.prev_month.beginning_of_month

    #   if Date.today.day == 1
    #     CANCELED_DATE = Date.new(prev_month.year, prev_month.month, 10)
    #   else
    #     CANCELED_DATE = Date.new(Date.today.year, Date.today.month, 1)
    #   end
    # end

    private

    def create_sbmi_folder(hios_prefix)
      @sbmi_folder_name = "DCHBX_SBMI_#{hios_prefix}_#{Time.now.strftime('%H_%M_%d_%m_%Y')}"
      create_directory "#{@sbmi_root_folder}/#{@sbmi_folder_name}"
    end

    def create_directory(path)
      if Dir.exists?(path)
        FileUtils.rm_rf(path)
      end
      Dir.mkdir path
    end

    def financial_headers
      ['Financial Start', 'Financial End', 'Premium', 'Aptc', 'Responsible Amount', 'Csr Variant'] + 2.times.inject([]) do |cols, i| 
        cols += ["Partial Premium", "Partial Aptc", "Partial Start", 'Partial End']
      end
    end

    def headers
      columns = ['Record Control Number','QHP ID', 'Policy EG ID', 'Subscriber HBXID', 'Policy Start', 'Policy End', 'Coverage Type']
      6.times {|i| columns += ["Covered Member HBX ID", "Is Subscriber", "First Name", "Last Name", "Middle Name","DOB", "SSN", "Gender", "Zipcode", "Member Start", "Member End"]}
      3.times {|i| columns += financial_headers}
      columns
    end

    def policies_to_skip
      ["208128","208671","212304","214429","214807","208674","246907","263444","263496","296902","300021"]
    end
  end
end
