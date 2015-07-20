require 'spreadsheet'
require 'csv'
module Generators::Reports  
  class IrsMonthlySerializer

    CALENDER_YEAR = 2014

    def initialize
      @logger = Logger.new("#{Rails.root}/log/h36_exceptions.log")

      @carriers = Carrier.all.inject({}){|hash, carrier| hash[carrier.id] = carrier.name; hash}
      @policy_family_hash = {}



      @h36_root_folder = "#{Rails.root}/irs/h36_#{Time.now.strftime('%m_%d_%Y_%H_%M')}"
      create_directory @h36_root_folder
    end

    def process    
      count = 0
      current = 0
      folder_count = 1

      missing_irs_groups = []
      multiple_taxhouseholds = []

      # create_directory(@h36_root_folder)
      # create_directory("#{@h36_root_folder}/transmission")
      # create_new_irs_folder(folder_count)

      # non_auth_families = 0
      # non_auth_pols = 0
      # families_with_no_coverage = 0

      start = Time.now
      Family.all.each do |family|
        current += 1

        if current % 100 == 0
          # puts "currently at #{current}"
        end

        begin

          next if family.households.count > 1 || family.active_household.nil? || family.primary_applicant.nil?
          next unless family.active_household.has_aptc?(CALENDER_YEAR)

          active_enrollments = family.active_household.enrollments_for_year(CALENDER_YEAR)
          next if active_enrollments.compact.empty?

          active_pols = active_enrollments.map(&:policy)
          next if active_pols.detect{|pol| pol.is_shop? }

          if family.irs_groups.empty?
            missing_irs_groups << family.e_case_id
            # puts "e_case_id --------- #{family.e_case_id}"
            next
          end

          # if active_pols.detect{|pol| pol.carrier_id.to_s == "53e67210eb899a460300000d"} || dupes.include?(family.e_case_id.to_i)
          #   count += 1
          # else
          #   non_authority_pols = active_enrollments.count { |enrollment| !enrollment.policy.belong_to_authority_member? }
          #   if non_authority_pols > 0
          #     non_auth_pols += non_authority_pols
          #     non_auth_families += 1
          #     if non_authority_pols == active_enrollments.count
          #       families_with_no_coverage += 1
          #     end
          #   end
          # end

          # build_policy_family_hash(active_pols, family)

          active_pols = nil

          # count += 1
          # next if active_enrollments.map(&:policy).any? {|pol| multi_version_aptc?(pol) }
          # policy_ids = active_enrollments.map(&:policy_id)
          # next if (policy_ids & policies_to_skip).any?

          active_enrollments = nil

          if family.family_members.any? {|x| x.person.authority_member.ssn == '999999999' }
            @logger.info "ssn with all 9's --- #{family.e_case_id.inspect}"
            next
          end

          if family.active_household.tax_households.count > 1
            multiple_taxhouseholds << family.e_case_id
            # puts family.e_case_id
          end

          family.active_household.tax_households.each do |th|
            th.primary
            th.spouse
            th.dependents
          end

          # irs_group = build_irs_group(family)

          # if irs_group.insurance_policies.empty?
          #   @logger.info "insurance policies empty --- #{family.e_case_id.inspect}"
          #   next
          # end

          # if irs_group.insurance_policies.any?{|policy| policy.no_coverage? || policy.no_premium_amount? }
          #   @logger.info "family has wrong policy --- #{family.e_case_id.inspect}"
          #   next
          # end

          # group_xml = IrsMonthlyXml.new(irs_group, family.e_case_id)
          # group_xml.folder_name = @h36_folder_name
          # group_xml.serialize

          # irs_group = nil
          # group_xml = nil

          # if count % 3200 == 0
          #   merge_and_validate_xmls(folder_count)
          #   folder_count += 1
          #   create_new_irs_folder(folder_count)
          # end

          # if count % 200 == 0
          #   puts "so far --- #{count} --- out of #{current}"
          #   puts "time taken for current record ---- #{Time.now - start} seconds"
          #   start = Time.now
          # end

        rescue Exception => e
          puts "Failed #{family.e_case_id}--#{e.to_s}"
        end
      end

      # print_families_with_samepolicy
      # merge_and_validate_xmls(folder_count)
      # create_manifest
      # true
      # puts count
      # puts missing_irs_groups.inspect
      # puts missing_irs_groups.count
      # puts multiple_taxhouseholds.count
      # puts multiple_taxhouseholds.inspect

      # puts count

      # puts non_auth_families
      # puts non_auth_pols
      # puts families_with_no_coverage
    end

    def build_irs_group(family)
      builder = Generators::Reports::IrsGroupBuilder.new(family)
      builder.carrier_hash = @carriers
      builder.calender_year = CALENDER_YEAR
      builder.process
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
      xml_merge.process
      xml_merge.validate
    end

    def create_manifest
      Generators::Reports::IrsMonthlyManifest.new.create("#{@h36_root_folder}/transmission")
    end

    private

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