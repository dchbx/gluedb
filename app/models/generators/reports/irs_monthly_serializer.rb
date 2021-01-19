require 'spreadsheet'
require 'csv'
module Generators::Reports  
  class IrsMonthlySerializer

    CALENDER_YEAR = 2019

    def initialize
      @logger = Logger.new("#{Rails.root}/log/h36_exceptions.log")

      @carriers = Carrier.all.inject({}){|hash, carrier| hash[carrier.id] = carrier.name; hash}
      puts @carriers.inspect
      
      @policy_family_hash = {}
      # load_npt_policies
      @npt_policies = []
      @settings = YAML.load(File.read("#{Rails.root}/config/irs_settings.yml")).with_indifferent_access

      @h36_root_folder = "#{Rails.root}/irs/h36_#{Time.now.strftime('%m_%d_%Y_%H_%M')}"
      create_directory @h36_root_folder
    end

    def load_npt_policies
      @npt_policies = []
      CSV.foreach("#{Rails.root}/2017_NPT_PolicyIds.csv", headers: :true) do |row|
        @npt_policies << row[0].strip 
      end
      puts @npt_policies.count
    end

    def process    
      current = 0
      folder_count = 1

      # missing_irs_groups = []
      # multiple_taxhouseholds = []

      create_directory("#{@h36_root_folder}/transmission")
      create_new_irs_folder(folder_count)

      # non_auth_families = 0
      # non_auth_pols = 0
      # families_with_no_coverage = 0
      # missing_active_enrollments = 0

      # book = Spreadsheet.open "#{Rails.root}/EXCLUSION_2015_H41_EOY_201602111545.xls"
      # skip_list = book.worksheets.first.inject([]){|data, row| data << row[0].to_s.strip.to_i}.compact

      workbook = Spreadsheet::Workbook.new
      sheet = workbook.create_worksheet :name => '2017 H36 QHP'

      index = 0
      count = 0
      check = 0

      columns = ['IRS GROUP NUMBER', 'TAX HOUSEHOLDS', 'PRIMARY FIRST NAME', 'PRIMARY LAST NAME', 'PRIMARY SSN', 'PRIMARY DOB', 'SPOUSE FIRST NAME', 'SPOUSE LAST NAME', 'SPOUSE SSN', 'SPOUSE DOB']
      5.times {|i| columns += ["DEPENDENT#{i+1} FIRST NAME", "DEPENDENT#{i+1} LAST NAME", "DEPENDENT#{i+1} SSN", "DEPENDENT#{i+1} DOB"]}
      columns += ['POLICY ID', 'PLAN ID', 'ISSUER NAME', 'ISSUER EIN', 'POLICY START', 'POLICY END']
      5.times {|i| columns += ["PREMIUM#{i+1}", "SLCSP#{i+1}", "APTC#{i+1}"]}

      sheet.row(index).concat columns
      start = Time.now

      Family.all.no_timeout.each do |family|
        current += 1

        if current % 100 == 0
          puts "currently at #{current}"
        end

        begin

          next if family.households.count > 1 || family.active_household.nil? 
          
          active_enrollments = family.active_household.enrollments_for_year(CALENDER_YEAR)
          active_enrollments.reject!{|e| e.policy.subscriber.coverage_start >= Date.today.beginning_of_month }
          active_enrollments.reject!{|e| policies_to_skip.include?(e.policy.id.to_s) }
          active_enrollments.reject!{|e| e.policy.kind == "coverall" }
          active_enrollments.reject! do |en|
            if en.policy.enrollees.any?{|en| en.person.authority_member.blank?}
              puts "#{en.policy.id} authority member missing!!"
              true
            else
              false
            end
          end

          next if active_enrollments.compact.empty?
          next if family.irs_groups.empty?

          active_enrollments = nil

          # active_pols = active_enrollments.map(&:policy)
          # if active_pols.detect{|x| skip_list.include?(x.id) }
          #   next
          # end

          # next unless family.active_household.tax_households.size == 0

          # non_authority_pols = active_enrollments.count { |enrollment| !enrollment.policy.belong_to_authority_member? }
          # if non_authority_pols > 0
          #   non_auth_pols += non_authority_pols
          #   non_auth_families += 1
          #   if non_authority_pols == active_enrollments.count
          #     families_with_no_coverage += 1
          #   end
          # end

          # build_policy_family_hash(active_pols, family)
          # active_pols = nil

          # count += 1

          # next if active_enrollments.map(&:policy).any? {|pol| multi_version_aptc?(pol) }
          # policy_ids = active_enrollments.map(&:policy_id)
          # next if (policy_ids & policies_to_skip).any?

          # if family.active_household.tax_households.count > 1
          #   # multiple_taxhouseholds << family.e_case_id
          #   # puts "---multiple tax households present"
          # elsif family.active_household.tax_households.count == 0
          #   # puts "-----no tax household----#{family.e_case_id}"
          # end

          # family.active_household.tax_households.each do |th|
          #   th.primary
          #   th.spouse
          #   th.dependents
          # end

          irs_group = build_irs_group(family)

          check += 1
          if check % 50 == 0
            puts "----found #{check} after check families so far"
          end

          if irs_group.insurance_policies.empty?
            puts "insurance policies empty --- #{family.e_case_id.inspect}"
            next
          end

          if irs_group.insurance_policies.any?{|policy| policy.no_coverage? || policy.no_premium_amount? }
            puts "family has wrong policy --- #{family.e_case_id.inspect}"
            next
          end

          # if irs_group.households[0].tax_households.empty?
          #   puts "EMPTY TAX HOUSEHOLDS #{family.e_case_id}"
          #   next
          # end

          # if irs_group.households[0].tax_households[0].primary.blank?
          #   puts "EMPTY TAX PRIMARY #{family.e_case_id}"
          #   next
          # end

          # puts irs_group.policies.inspect

          # ENABLE THIS FOR CSV EXPORT
          # rows = irs_group.to_csv
          # if rows.present?
          #   rows.each do |row|
          #     index += 1
          #     sheet.row(index).concat row

          #     if index % 50 == 0
          #       puts "----found #{index} index families so far"
          #     end
          #   end
          # end

          group_xml = IrsMonthlyXml.new(irs_group, family.e_case_id)
          group_xml.folder_path = "#{@h36_root_folder}/#{@h36_folder_name}"
          group_xml.serialize

          irs_group = nil
          group_xml = nil

          count += 1

          if count % 50 == 0
            puts "----found #{count} families so far"
          end

          if count % 3000 == 0
            merge_and_validate_xmls(folder_count)
            folder_count += 1
            create_new_irs_folder(folder_count)
          end

          if count % 100 == 0
            puts "so far --- #{count} --- out of #{current}"
            puts "time taken for current record ---- #{Time.now - start} seconds"
            start = Time.now
          end

        rescue Exception => e
         puts "Failed #{family.e_case_id}--#{e.to_s}"
      end
      end

      # print_families_with_samepolicy

      merge_and_validate_xmls(folder_count)
      create_manifest

      # workbook.write "#{Rails.root.to_s}/2016_H36_QHP_DATA_EXPORT#{Time.now.strftime("%m_%d_%Y_%H_%M")}.xls"

      puts count
      # puts multiple

      # puts missing_irs_groups.inspect
      # puts missing_irs_groups.count

      # puts multiple_taxhouseholds.count
      # puts multiple_taxhouseholds.inspect

      # puts non_auth_families
      # puts non_auth_pols
      # puts families_with_no_coverage
      # puts missing_active_enrollments
    end

    def build_irs_group(family)
      builder = Generators::Reports::IrsGroupBuilder.new(family)
      builder.carrier_hash = @carriers
      builder.npt_policies = @npt_policies
      builder.calender_year = CALENDER_YEAR
      builder.settings = @settings
      builder.process
      builder.npt_policies = []
      builder.irs_group
    end

    def print_families_with_samepolicy
      @policy_family_hash.each do |policy_id, ecases|
        if ecases.count > 1
          puts "#{policy_id}---#{ecases.join(',').inspect}"
        end
      end   
    end

    def build_policy_family_hash(active_pols, family)
      active_pols.each do |pol|
        if @policy_family_hash.has_key?(pol.id)
          @policy_family_hash[pol.id] = @policy_family_hash[pol.id] + [family.e_case_id]
        else
          @policy_family_hash[pol.id] = [family.e_case_id]
        end
      end
    end

    def merge_and_validate_xmls(folder_count)
      folder_num = prepend_zeros(folder_count.to_s, 5)
      xml_merge = Generators::Reports::IrsXmlMerger.new("#{@h36_root_folder}/#{@h36_folder_name}", folder_num)
      xml_merge.irs_monthly_folder = @h36_root_folder
      xml_merge.process
      xml_merge.validate
    end

    def create_manifest
      Generators::Reports::IrsMonthlyManifest.new.create("#{@h36_root_folder}/transmission")
    end

    private

    def policies_to_skip
      ["208128","208671","212304","214429","214807","208674","246907","263444","263496","296902","300021"]
    end

    def create_new_irs_folder(folder_count)
      folder_number = prepend_zeros(folder_count.to_s, 3)
      @h36_folder_name = "DCHBX_H36_#{Time.now.strftime('%H_%M_%d_%m_%Y')}_#{folder_number}"
      create_directory "#{@h36_root_folder}/#{@h36_folder_name}"
    end

    def prepend_zeros(number, n)
      (n - number.to_s.size).times { number.prepend('0') }
      number
    end

    def create_directory(path)
      if Dir.exists?(path)
        FileUtils.rm_rf(path)
      end
      Dir.mkdir path
    end
  end
end
