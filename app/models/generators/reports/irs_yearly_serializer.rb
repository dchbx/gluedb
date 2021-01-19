require 'spreadsheet'
require 'csv'
module Generators::Reports  
  class IrsYearlySerializer

    IRS_XML_PATH = "#{@irs_path}/h41/"
    IRS_PDF_PATH = "#{@irs_path}/irs1095a/"

    attr_accessor :notice_params, :calender_year, :qhp_type, :notice_absolute_path, :xml_output

    def initialize(options = {})
      @count = 0
      @policy_id = nil
      @hbx_member_id = nil

      @report_names = {}
      @xml_output = false

      @pdf_set  = 0
      @irs_set  = 0
      @notice_params = options

      if options.empty?
        irs_path = "#{Rails.root.to_s}/irs/irs_EOY_#{Time.now.strftime('%m_%d_%Y_%H_%M')}"
        create_directory irs_path

        if xml_output
          @irs_xml_path = irs_path + "/h41/"
          create_directory @irs_xml_path
          create_directory @irs_xml_path + "/transmission"
        else
          @irs_pdf_path = irs_path + "/irs1095a/"
          create_directory @irs_pdf_path
        end
      end

      @carriers = Carrier.all.inject({}){|hash, carrier| hash[carrier.id] = carrier.name; hash}
      @settings = YAML.load(File.read("#{Rails.root}/config/irs_settings.yml")).with_indifferent_access
    end

    def load_npt_data
      book = Spreadsheet.open "#{Rails.root}/2018_NPT_data.xls"
      @npt_list = book.worksheets.first.inject([]){|data, row| data << row[0].to_s.strip.to_i}.compact
      puts "Found #{@npt_list.count} in npt_list"
    end

    def load_responsible_party_data
      book = Spreadsheet.open "#{Rails.root}/2018_RP_data.xls"
      @responsible_party_data = book.worksheets.first.inject({}) do |data, row|
        if row[3].to_s.strip.match(/Responsible Party SSN/i) || (row[3].to_s.strip.blank? && row[5].to_s.strip.blank?)
        else
          data[row[0].to_s.strip.to_i] = [prepend_zeros(row[3].to_i.to_s, 9), Date.strptime(row[4].to_s.split("T")[0], "%m/%d/%Y")]
        end
        data
      end
      puts "Found #{@responsible_party_data.keys.count} RP entries"
    end

    def create_enclosed_folder
      if xml_output
        create_new_irs_folder
      else
        create_new_pdf_folder
      end
    end

    def build_notice_params(policy)
      @notice_params[:npt]  =  @npt_list.include?(policy.id)
      @notice_params[:type] = 'new'
    end

    def create_excel_workbook
      workbook = Spreadsheet::Workbook.new
      @sheet = workbook.create_worksheet :name => 'QHP'
      columns = ['POLICY ID', 'Subscriber Hbx ID', 'Recipient Address']
      5.times {|i| columns += ["NAME#{i+1}", "SSN#{i+1}", "DOB#{i+1}", "BEGINDATE#{i+1}", "ENDDATE#{i+1}"]}
      columns += ['ISSUER NAME']
      12.times {|i| columns += ["PREMIUM#{i+1}", "SLCSP#{i+1}", "APTC#{i+1}"]}
      @sheet.row(@count).concat columns
      workbook
    end

    def generate_notices
      create_enclosed_folder
      load_npt_data
      load_responsible_party_data
      workbook = create_excel_workbook

      count = 0
      @folder_count = 1

      policies_by_subscriber.each do |row, policies|
        policies.each do |policy|

          begin
            next if policy.plan.metal_level =~ /catastrophic/i
            next if policy.kind == 'coverall'

            count += 1
            if count % 1000 == 0
              puts count
            end

            next if count > 300

            if policy.responsible_party_id.present?
              if @responsible_party_data[policy.id].blank?
                puts "RP data missing for #{policy.id}"
                next
              end
            end

            build_notice_params(policy)

            # next if (policy.applied_aptc > 0 || policy.multi_aptc?)
            # next unless (policy.subscriber.coverage_end.present? && (policy.subscriber.coverage_end.end_of_month != policy.subscriber.coverage_end))

            process_policy(policy)

          rescue Exception => e
            puts policy.id
            puts e.to_s.inspect
          end
        end
      end

      workbook.write "#{Rails.root.to_s}/IVL_QHP_1095A_#{Time.now.strftime("%m_%d_%Y_%H_%M")}.xls"

      if xml_output
        merge_and_validate_xmls(@folder_count)
        create_manifest
      end
    end

    def process_corrected_h41
      create_new_irs_folder

      @corrected_h41_policies = {}
      CSV.foreach("#{Rails.root}/2018_H41_Corrected_20180807.csv") do |row|
        @corrected_h41_policies[row[0].strip] = row[1].strip
      end

      @npt_policies = []
      CSV.foreach("#{Rails.root}/2017_NPT_UQHP_20180126.csv", headers: :true) do |row|
        @npt_policies << row[0].strip
      end

      count = 0
      @folder_count = 1

      @corrected_h41_policies.keys.each do |policy_id|
        policy = Policy.find(policy_id)

        # begin
          next if policy.plan.metal_level =~ /catastrophic/i
          next if policy.kind == 'coverall'

          count += 1
          if count % 1000 == 0
            puts count
          end

          if policy.responsible_party_id.present?
            puts "found responsible party #{policy.id}"
          end
          
          notice_params[:type] = 'corrected'
   
          if @npt_policies.include?(policy.id.to_s)
            notice_params[:npt] = true
          else
            notice_params[:npt] = false
          end

          process_policy(policy)
        # rescue Exception => e
        #   puts policy.id
        #   puts e.to_s.inspect
        # end
      end
      merge_and_validate_xmls(@folder_count)
      create_manifest
    end

    def process_voided_h41
      create_new_irs_folder

      @void_policies = {}
      CSV.foreach("#{Rails.root}/2018_H41_Voided_20180807.csv") do |row|
        @void_policies[row[0].strip] = row[1].strip
      end

      @npt_policies = []
      CSV.foreach("#{Rails.root}/2017_NPT_UQHP_20180126.csv", headers: :true) do |row|
        @npt_policies << row[0].strip
      end

      count = 0
      @folder_count = 1

      @void_policies.keys.each do |policy_id|
        policy = Policy.find(policy_id)

        begin
          next if policy.plan.metal_level =~ /catastrophic/i
          next if policy.kind == 'coverall'

          count += 1
          if count % 1000 == 0
            puts count
          end

          if policy.responsible_party_id.present?
            puts "found responsible party #{policy.id}"
          end
            
          notice_params[:type] = 'void'

          if @npt_policies.include?(policy.id.to_s)
            notice_params[:npt] = true
          else
            notice_params[:npt] = false
          end

          process_policy(policy)
        rescue Exception => e
          puts policy.id
          puts e.to_s.inspect
        end
      end
      merge_and_validate_xmls(@folder_count)
      create_manifest
    end

    def process_policy_ids(ids)
      create_new_pdf_folder
      create_new_irs_folder

      # book = Spreadsheet.open "#{Rails.root}/Responsible_Party_3_10.xls"
      # @responsible_party_data = book.worksheets.first.inject({}) do |data, row|
      #   if row[2].to_s.strip.match(/Responsible Party SSN/i) || (row[2].to_s.strip.blank? && row[3].to_s.strip.blank?)
      #   else
      #     data[row[0].to_s.strip.to_i] = [prepend_zeros(row[2].to_i.to_s, 9), Date.strptime(row[3].to_s.strip, "%m-%d-%Y")]
      #   end
      #   data
      # end


      book = Spreadsheet.open "#{Rails.root}/CF_Responsible_Party_1095A_February_Standard_Assisted_20170224.xls"
      @responsible_party_data = book.worksheets.first.inject({}) do |data, row|
        if row[2].to_s.strip.match(/Responsible Party SSN/i) || (row[2].to_s.strip.blank? && row[3].to_s.strip.blank?)
        else
          if row[2].to_s.strip.blank?
            data[row[0].to_s.strip.to_i] = [nil, Date.strptime(row[3].to_s.split("T")[0], "%Y-%m-%d")]
          else
            data[row[0].to_s.strip.to_i] = [prepend_zeros(row[2].to_i.to_s, 9), Date.strptime(row[3].to_s.split("T")[0], "%Y-%m-%d")]
          end
        end
        data
      end

      puts @responsible_party_data.inspect

      ids.each do |id|
        id = Policy.find(id)
        process_policy(id)
      end
    end

    def generate_notice
      set_default_directory
      policy = Policy.find(notice_params[:policy_id])
      if policy.responsible_party_id.present?
        return if notice_params[:responsible_party_ssn].blank? && notice_params[:responsible_party_dob].blank?

        if notice_params[:responsible_party_ssn].present?
          ssn = prepend_zeros(notice_params[:responsible_party_ssn].gsub('-','').to_i.to_s, 9)
        end

        @responsible_party_data = { 
          policy.id => [ssn, notice_params[:responsible_party_dob]]
        }
      end

      if notice_params[:type] == 'void'
        process_canceled_policy(policy, notice_params[:void_cancelled_policy_ids].join(','), notice_params[:void_active_policy_ids].join(','))
      else
        process_policy(policy)
      end

      notice_absolute_path
    end

    def set_default_directory
      @irs_pdf_path = Rails.root.to_s + @settings[:tax_document][:documents_root_path]
      @irs1095_folder_name = @settings[:tax_document][:documents_folder]
      notices_path = @irs_pdf_path + @irs1095_folder_name

      if !Dir.exists?(notices_path)
        Dir.mkdir notices_path
      end
    end

    def valid_policy?(policy, h41 = nil)
      return true if h41.present?
      active_enrollees = policy.enrollees.reject{|en| en.canceled?}
      return false if active_enrollees.empty?
      if rejected_policy?(policy) || policy.canceled? || !policy.belong_to_authority_member?
        return false
      end

      if policy.subscriber.coverage_end.present? && (policy.subscriber.coverage_end < policy.subscriber.coverage_start)
        return false
      end

      true
    end

    def build_notice_input(policy)
      irs_input = Generators::Reports::IrsInputBuilder.new(policy, { notice_type: notice_params[:type], npt_policy: notice_params[:npt] })
      irs_input.carrier_hash = @carriers
      irs_input.settings = @settings
      irs_input.process
      irs_input
    end

    def generate_h41
      policy = Policy.find(notice_params[:policy_id])
      begin
        process_policy(policy, true)
      rescue => e
        puts policy.id unless Rails.env.test?
        puts e.to_s.inspect unless Rails.env.test?
      end
      find_or_create_directory "#{Rails.root}/H41_federal_report"
      create_individual_manifest
      FileUtils.cd(@h41_folder_name)
      `zip #{@h41_folder_name}.zip *`
      `mv #{@h41_folder_name}.zip ..`
      FileUtils.cd("..")
      `mv #{@h41_folder_name}/* "#{Rails.root}/H41_federal_report"`
      return "#{@h41_folder_name}.zip" if File.exists?("#{@h41_folder_name}.zip")
    end

    def process_policy(policy, h41 = nil)

       if valid_policy?(policy, h41)
        @calender_year = policy.subscriber.coverage_start.year
        notice_params[:calender_year] = @calender_year.to_s
        @qhp_type  = ((policy.applied_aptc > 0 || policy.multi_aptc?) ? 'assisted' : 'unassisted')
        @policy_id = policy.id
        @hbx_member_id = policy.subscriber.person.authority_member.hbx_member_id

        irs_input = build_notice_input(policy)

        if policy.responsible_party_id.present?
          if responsible_party = Person.where("responsible_parties._id" => Moped::BSON::ObjectId.from_string(policy.responsible_party_id)).first
            puts "responsible party address attached"          
            irs_input.append_recipient_address(responsible_party)
            # irs_input.append_recipient(responsible_party)
          end
          puts "----responsible party"
          # return
        end

        notice = irs_input.notice
        if (notice.recipient_address.to_s.match(/609 H St NE/i).present? || notice.recipient_address.to_s.match(/1225 Eye St NW/i).present?)
          puts notice.recipient_address.to_s
          return
        end

        notice.active_policies = []
        notice.canceled_policies = []
        if xml_output
          create_report_names
          render_xml(notice)

          if @count != 0 && @count % 4000 == 0
            merge_and_validate_xmls(@folder_count)
            @folder_count += 1
            create_new_irs_folder
          end
        elsif h41
          @count = 1
          sequential_number = @count.to_s
          sequential_number = prepend_zeros(sequential_number, 5)
          @report_names = {
            xml: "EOY_Request_#{sequential_number}_#{Time.now.utc.iso8601.gsub(/-|:/,'')}"
          }
          create_individual_h41_folder
          xml = render_individual_h41_xml(notice)
        else
          create_report_names
          render_pdf(notice)
          #append_report_row(notice)

          if notice.covered_household.size > 5
            create_report_names
            render_pdf(notice, true)
            append_report_row(notice, true)   
          end

          if @count != 0 && (@count % 1000 == 0)
            create_new_pdf_folder
          end
        end

        notice = nil
        policy = nil
       end
    end

    def append_report_row(notice, multiple = false)
      @sheet.row(@count).concat Generators::Reports::IrsInputExportBuilder.new(notice, multiple).excel_row
    end

    def process_canceled_pols
      create_new_pdf_folder
      create_new_irs_folder

      # CSV.foreach("#{Rails.root}/INCLUSION_REDMINE_2014_20160324_VOID_Request_5843-6232.csv") do |row|

      # book = Spreadsheet.open "#{Rails.root}/Responsible_Party_8_18_16_SSN_Added.xls"
      # # book = Spreadsheet.open "#{Rails.root}/Responsible_Party_3_10_16_SSN_Added_2_2014.xls"
      # @responsible_party_data = book.worksheets.first.inject({}) do |data, row|
      #   if row[2].to_s.strip.match(/Responsible Party SSN/i) || (row[2].to_s.strip.blank? && row[3].to_s.strip.blank?)
      #   else
      #     data[row[0].to_s.strip.to_i] = [prepend_zeros(row[2].to_i.to_s, 9), Date.strptime(row[3].to_s.strip, "%m-%d-%Y")]
      #   end
      #   data
      # end

      CSV.foreach("#{Rails.root}/CF_1095_Revisions_February_20170223_VOID.csv") do |row|
        policy_id = row[0].strip

        puts "processing #{policy_id}"
        policy = Policy.find(policy_id)

        if policy.responsible_party_id.present?
          puts "found responsible party --------------------- #{policy.id}"
          next
        end

        process_canceled_policy(policy, convert_to_policy_identifiers(row[1]), convert_to_policy_identifiers(row[2]))

        if @count !=0
          if (@count % 250 == 0)
            create_new_pdf_folder
          elsif (@count % 4000 == 0)
            create_new_irs_folder
          end
        end

        notice = nil
        policy = nil
      end
    end

    def process_canceled_policy(policy, canceled_policies, active_policies)
      @calender_year = policy.subscriber.coverage_start.year
      @policy_id = policy.id
      @hbx_member_id = policy.subscriber.person.authority_member.hbx_member_id
      irs_input = Generators::Reports::IrsInputBuilder.new(policy, {void: true})
      irs_input.carrier_hash = @carriers
      irs_input.settings = @settings
      irs_input.process

      if policy.responsible_party_id.present?
        if responsible_party = Person.where("responsible_parties._id" => Moped::BSON::ObjectId.from_string(policy.responsible_party_id)).first
          puts "responsible party address attached"          
          irs_input.append_recipient_address(responsible_party)
        end  
      end

      notice = irs_input.notice
      notice.canceled_policies = canceled_policies
      notice.active_policies = active_policies

      create_report_names
      render_pdf(notice, false, true)
    end

    def convert_to_policy_identifiers(row)
      return '' if row.blank?
      row.split(',').join(', ')
    end

    def generate_irs_transmission_for_voids(file)
      create_new_irs_folder
      CSV.foreach("#{Rails.root}/#{file}") do |row|
        policy_id = row[0].strip
        record_seq_num = row[1].strip

        policy = Policy.find(policy_id)

        @policy_id = policy.id
        @hbx_member_id = policy.subscriber.person.authority_member.hbx_member_id

        notice = Generators::Reports::IrsInputBuilder.new(policy, void: true).notice
        notice.corrected_record_seq_num = record_seq_num

        create_report_names
        render_xml(notice)

        notice = nil
        policy = nil
      end      
    end

    def create_manifest
      Generators::Reports::IrsYearlyManifest.new.create("#{@irs_xml_path}/transmission")
    end

    def create_individual_manifest
      Generators::Reports::IrsYearlyManifest.new.create("#{@h41_folder_name}", notice_params)
    end

    def rejected_policy?(policy)
      edi_transactions = Protocols::X12::TransactionSetEnrollment.where({ "policy_id" => policy.id })
      return true if edi_transactions.size == 1 && edi_transactions.first.aasm_state == 'rejected'
      false
    end

    def create_report_names
      @count += 1
      sequential_number = @count.to_s
      sequential_number = prepend_zeros(sequential_number, 6)

      name_prefix = (notice_params[:type] == 'new' ? "IRS1095A" : "IRS1095ACorrected")
     
      @report_names = {
        pdf: "#{name_prefix}_#{calender_year}_#{Time.now.strftime('%Y%m%d')}_#{@hbx_member_id}_#{@policy_id}_#{sequential_number}",
        # pdf: "IRS1095A_2016_#{Time.now.strftime('%Y%m%d')}_#{@hbx_member_id}_#{@policy_id}_#{sequential_number}",
        # pdf: "IRS1095A_2015_#{Time.now.strftime('%Y%m%d')}_#{@hbx_member_id}_#{@policy_id}_#{sequential_number}",
        # pdf: "#{sequential_number}_HBX_01_#{@hbx_member_id}_#{@policy_id}_IRS1095A_Corrected",
        # pdf: "#{sequential_number}_HBX_01_#{@hbx_member_id}_#{@policy_id}_IRS1095A",
        xml: "EOY_Request_#{sequential_number}_#{Time.now.utc.iso8601.gsub(/-|:/,'')}"
      }
    end


    def render_individual_h41_xml(notice)
      yearly_xml_generator = Generators::Reports::IrsYearlyXml.new(notice, notice_params)
      yearly_xml_generator.corrected_record_sequence_num = notice.policy_id if notice_params[:type] == "corrected"
      yearly_xml_generator.voided_record_sequence_num = notice.policy_id if notice_params[:type] == "void"

      xml_report = yearly_xml_generator.serialize.to_xml(:indent => 2)

      File.open("#{@irs_xml_path + @h41_folder_name}/#{@report_names[:xml]}.xml", 'w') do |file|
        file.write xml_report
      end
    end

    def render_xml(notice)
      yearly_xml_generator = Generators::Reports::IrsYearlyXml.new(notice, notice_params)
      yearly_xml_generator.corrected_record_sequence_num = @corrected_h41_policies[notice.policy_id] if @corrected_h41_policies.present?
      yearly_xml_generator.voided_record_sequence_num = @void_policies[notice.policy_id] if @void_policies.present?

      xml_report = yearly_xml_generator.serialize.to_xml(:indent => 2)

      

      File.open("#{@irs_xml_path + @h41_folder_name}/#{@report_names[:xml]}.xml", 'w') do |file|
        file.write xml_report
      end
    end

    def render_pdf(notice, multiple = false, void = false)
      options = {multiple: multiple, calender_year: calender_year, qhp_type: qhp_type, notice_type: 'new'}

      if void
        options.merge({notice_type: 'void'})
      end

      if notice_params.present?
        options = { multiple: multiple, calender_year: calender_year, qhp_type: qhp_type, notice_type: notice_params[:type]}
      end

      if notice.active_policies.blank?
        options.merge!({void_type: 'active_false'})
      else
        options.merge!({void_type: 'active_true'})
      end

      pdf_notice = Generators::Reports::IrsYearlyPdfReport.new(notice, options)
      pdf_notice.settings = @settings
      pdf_notice.responsible_party_data = @responsible_party_data[notice.policy_id.to_i] if @responsible_party_data.present? # && ![87085,87244,87653,88495,88566,89129,89702,89922,95250,115487].include?(notice.policy_id.to_i)
      pdf_notice.process
      @notice_absolute_path = "#{@irs_pdf_path + @irs1095_folder_name}/#{@report_names[:pdf]}.pdf"
      pdf_notice.render_file(@notice_absolute_path)
    end

    def create_new_pdf_folder
      @pdf_set += 1
      folder_number = prepend_zeros(@pdf_set.to_s, 3)
      @irs1095_folder_name = "DCEXCHANGE_#{Time.now.strftime('%Y%m%d')}_1095A_#{folder_number}"
      create_directory @irs_pdf_path + @irs1095_folder_name
    end

    def create_new_irs_folder
      @irs_set += 1
      folder_number = prepend_zeros(@irs_set.to_s, 3)
      @h41_folder_name = "DCHBX_H41_#{Time.now.strftime('%H_%M_%d_%m_%Y')}_#{folder_number}"
      create_directory @irs_xml_path + @h41_folder_name
    end

    def create_individual_h41_folder
      @irs_xml_path = ''
      @h41_folder_name ||= "FEP0020DC.DSH.EOYIN.D#{Time.now.strftime('%Y%m%d')[2..-1]}.T#{Time.now.strftime("%H%M%S") + "000"}.P.IN"
      find_or_create_directory @irs_xml_path + @h41_folder_name
    end

    def find_or_create_directory(path)
      return path if Dir.exists?(path)
      FileUtils.mkdir_p(path)
    end

    def create_directory(path)
      if Dir.exists?(path)
        FileUtils.rm_rf(path)
      end
      FileUtils.mkdir_p(path)
    end

    def prepend_zeros(number, n)
      (n - number.to_s.size).times { number.prepend('0') }
      number
    end

    def policies_by_subscriber
      # carrier = Carrier.where(:name => "CareFirst").first
      # plans = Plan.where({:metal_level => {"$not" => /catastrophic/i}, :coverage_type => /health/i, :carrier_id => carrier.id}).map(&:id)
      # plans = Plan.where({:metal_level => /catastrophic/i, :coverage_type => /health/i}).map(&:id)

      plans = Plan.where({:metal_level => {"$not" => /catastrophic/i}, :coverage_type => /health/i}).map(&:id)

      p_repo = {}

      # p_map = Person.collection.aggregate([{"$unwind"=> "$members"}, {"$project" => {"_id" => 0, member_id: "$members.hbx_member_id", person_id: "$_id"}}])
      # p_map.each do |val|
      #   p_repo[val["member_id"]] = val["person_id"]
      # end

      Person.no_timeout.each do |person|
        person.members.each do |member|
          p_repo[member.hbx_member_id] = person._id
        end
      end

      pols = PolicyStatus::Active.between(Date.new(2017,12,31), Date.new(2018,12,31)).results.where({
        :plan_id => {"$in" => plans}, :employer_id => nil
        }).group_by { |p| p_repo[p.subscriber.m_id] }
    end

    def merge_and_validate_xmls(folder_count)
      folder_num = prepend_zeros(folder_count.to_s, 5)
      xml_merge = Generators::Reports::IrsYearlyXmlMerger.new("#{@irs_xml_path + @h41_folder_name}", folder_num, notice_params)
      xml_merge.irs_yearly_xml_folder = @irs_xml_path
      xml_merge.process
      xml_merge.validate
    end
  end
end
