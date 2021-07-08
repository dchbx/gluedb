require 'spreadsheet'
require 'csv'
module Generators::Reports  
  class IrsYearlySerializer

    IRS_XML_PATH = "#{@irs_path}/h41/"
    IRS_PDF_PATH = "#{@irs_path}/irs1095a/"

    attr_accessor :notice_params, :calender_year, :qhp_type, :notice_absolute_path

    def initialize(options = {})
      @count = 0
      @policy_id = nil
      @hbx_member_id = nil

      @report_names = {}
      @policies = []
      @plans    = nil

      @position = 0
      @pdf_set  = 1
      @irs_set  = 0
      @aptc_versions = []

      @notice_params = options

      if options.empty?
        irs_path = "#{Rails.root.to_s}/irs/irs_EOY_#{Time.now.strftime('%m_%d_%Y_%H_%M')}"
        @irs_pdf_path = irs_path + "/irs1095a/"

        create_directory irs_path
        create_directory @irs_pdf_path

        @irs_xml_path = irs_path + "/h41/"
        create_directory @irs_xml_path
        create_directory @irs_xml_path + "/transmission"
      end

      @carriers = Carrier.all.inject({}){|hash, carrier| hash[carrier.id] = carrier.name; hash}
      @settings = YAML.load(File.read("#{Rails.root}/config/irs_settings.yml")).with_indifferent_access
    end


    def generate_notices
      create_new_pdf_folder
      create_new_irs_folder

      # book = Spreadsheet.open "#{Rails.root}/KP_2016_1095_COMPILED_EXCLUSION_LIST_SET2.xls"
      # skip_list = book.worksheets.first.inject([]){|data, row| data << row[2].to_s.strip.to_i}.compact

      # puts "Found #{skip_list.count} in skip_list"

      # book = Spreadsheet.open "#{Rails.root}/2016_H41_RP_Policy_Info.xls"
      # inclusion_list = book.worksheets.first.inject([]){|data, row| data << row[0].to_s.strip.to_i}.compact

      # puts "Found #{inclusion_list.count} in responsible_party_list"


      book = Spreadsheet.open "#{Rails.root}/2016_1095_NPT_Policies_For_2016_H41.xls"
      @npt_list = book.worksheets.first.inject([]){|data, row| data << row[0].to_s.strip.to_i}.compact
      puts "Found #{@npt_list.count} in npt_list"

      book = Spreadsheet.open "#{Rails.root}/2016_H41_RP_Policy_Info.xls"
      @responsible_party_data = book.worksheets.first.inject({}) do |data, row|
        if row[2].to_s.strip.match(/Responsible Party SSN/i) || (row[2].to_s.strip.blank? && row[4].to_s.strip.blank?)
        else
          data[row[0].to_s.strip.to_i] = [prepend_zeros(row[2].to_i.to_s, 9), Date.strptime(row[3].to_s.split("T")[0], "%Y-%m-%d")]
        end
        data
      end

      count = 0
      @folder_count = 1

      policies_by_subscriber.each do |row, policies|
        policies.each do |policy|

          # begin
          # next unless  policy.plan.metal_level =~ /catastrophic/i

            count += 1
            if count % 1000 == 0
              puts count
            end

            # next unless inclusion_list.include?(policy.id)


            # next if skip_list.include?(policy.id)

            # if policy.responsible_party_id.present?
            #   # puts "found responsible party #{policy.id}"
            #   next
            # end

            # next unless (policy.applied_aptc > 0 || policy.multi_aptc?)
            # next unless kaiser_plans.include?(policy.plan_id)
            # next if policy.subscriber.coverage_end.present? && (policy.subscriber.coverage_end < policy.subscriber.coverage_start)
            # next unless (policy.subscriber.coverage_end.present? && (policy.subscriber.coverage_end.end_of_month != policy.subscriber.coverage_end))
            # next if policy.canceled?
            # next if rejected_policy?(policy)

            # if @responsible_party_data[policy.id].blank?
            #   puts "data missing for #{policy.id}"
            #   next
            # end
            
            process_policy(policy)

          # rescue Exception => e
          #   puts policy.id
          #   puts e.to_s.inspect
          # end
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

    # Generators::Reports::IrsYearlySerializer.new({policy_id: 123584, type: 'new', npt: false}).generate_notice

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

    def valid_policy?(policy)
      active_enrollees = policy.enrollees.reject{|en| en.canceled?}

      if active_enrollees.empty?
        return false
      end

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

    def process_policy(policy)
      if valid_policy?(policy)
        @calender_year = policy.subscriber.coverage_start.year
        @qhp_type = ((policy.applied_aptc > 0 || policy.multi_aptc?) ? 'assisted' : 'unassisted')
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

        create_report_names
        # render_xml(notice)

        render_pdf(notice)

        if notice.covered_household.size > 5
          create_report_names
          render_pdf(notice, true)          
        end

        if @count !=0
          if (@count % 250 == 0)
            create_new_pdf_folder
          elsif (@count % 4000 == 0)
            create_new_irs_folder
          end
        end

        if @count % 4000 == 0
          merge_and_validate_xmls(@folder_count)
          @folder_count += 1
          create_new_irs_folder
        end

        notice = nil
        policy = nil
      end
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
      Generators::Reports::Manifest.new.create("#{@irs_xml_path + @h41_folder_name}")
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

    def render_xml(notice)
      xml_report = Generators::Reports::IrsYearlyXml.new(notice).serialize.to_xml(:indent => 2)
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

    def create_directory(path)
      if Dir.exists?(path)
        FileUtils.rm_rf(path)
      end
      Dir.mkdir path
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

      p_map = Person.collection.aggregate([{"$unwind"=> "$members"}, {"$project" => {"_id" => 0, member_id: "$members.hbx_member_id", person_id: "$_id"}}])

      p_map.each do |val|
        p_repo[val["member_id"]] = val["person_id"]
      end

      pols = PolicyStatus::Active.between(Date.new(2015,12,31), Date.new(2016,12,31)).results.where({
        :plan_id => {"$in" => plans}, :employer_id => nil
        }).group_by { |p| p_repo[p.subscriber.m_id] }
    end

    def merge_and_validate_xmls(folder_count)
      folder_num = prepend_zeros(folder_count.to_s, 5)
      xml_merge = Generators::Reports::IrsYearlyXmlMerger.new("#{@irs_xml_path + @h41_folder_name}", folder_num)
      xml_merge.irs_yearly_xml_folder = @irs_xml_path
      xml_merge.process
      xml_merge.validate
    end
  end
end