module Parsers
  module Edi
    class TransmissionFile
      attr_reader :result
      attr_accessor :transmission_kind
      
      def initialize(path, t_kind, r_data, blist = [], i_cache, pb)
        @raw = r_data
        @progress_bar = pb
        @result = Oj.load(r_data)
        @progress_bar.refresh
        @file_name = File.basename(path)
        @transmission_kind = t_kind
        @inbound = (t_kind == "effectuation")
        @bgn_blacklist = blist
        @import_cache = i_cache
      end

      def transaction_set_kind(etf)
        if(@transmission_kind == "effectuation" && etf.cancellation_or_termination?)
          return "maintenance"
        end
        @transmission_kind
      end

      def persist_edi_transactions(
        l834,
        policy_id,
        carrier_id,
        employer_id,
        edi_transmission,
        error_list = [])
        st = l834["ST"]
        bgn = l834["BGN"]
        fs = FileString.new(bgn[2] + "_" + @file_name, l834["RAW_CONTENT"])
        etf = Etf::EtfLoop.new(l834)
        @progress_bar.refresh
        Protocols::X12::TransactionSetEnrollment.create!(
          :st01 => st[1],
          :st02 => st[2],
          :st03 => st[3],
          :bgn01 => bgn[1],
          :bgn02 => bgn[2],
          :bgn03 => bgn[3],
          :bgn04 => bgn[4],
          :bgn05 => bgn[5],
          :bgn06 => bgn[6],
          :bgn08 => bgn[8],
          :carrier_id => carrier_id,
          :receiver_id => edi_transmission.isa08,
          :employer_id => employer_id,
          :policy_id => policy_id,
          :error_list => error_list,
          :transmission => edi_transmission,
          :transaction_kind => transaction_set_kind(etf),
          :body => fs
        )
      end

      def parse_edi_transmission(top_doc)
        isa = top_doc["ISA"]
        gs = top_doc["GS"]
        sender_id = isa[6].strip
        Protocols::X12::Transmission.create!({
          :isa06 => sender_id,
          :isa08 => isa[8].strip,
          :isa09 => isa[9].strip,
          :isa10 => isa[10].strip,
          :isa12 => isa[12].strip,
          :isa13 => isa[13].strip,
          :isa15 => isa[15].strip,
          :gs01 => gs[1],
          :gs02 => gs[2],
          :gs03 => gs[3],
          :gs04 => gs[4],
          :gs05 => gs[5],
          :gs06 => gs[6],
          :gs07 => gs[7],
          :gs08 => gs[8],
          :file_name => @file_name
        })
      end

      def persist_834(etf_loop, edi_transmission)
        etf = Etf::EtfLoop.new(etf_loop)

        # Carrier
        carrier = @import_cache.lookup_carrier_fein(etf.carrier_fein)

        # Employer
        employer = nil
        if(etf.is_shop?)
          employer_loop = Etf::EmployerLoop.new(etf.employer_loop)
          employer = persist_employer(employer_loop, carrier._id)

          if(employer.nil?)
            raise("Unknown employer ID: #{employer_loop.id_qualifier} #{employer_loop.fein}")
          end
        end
        employer_id = Maybe.new(employer)._id.value

        #Policy
        policy_loop = etf.subscriber_loop.policy_loops.first
        plan_year = nil
        plan = nil
        coverage_start = Maybe.new(policy_loop.coverage_start).fmap { |cs| Date.parse(cs) }.value
        if !coverage_start.nil?
          if(etf.is_shop?)
            plan_year = PlanYear.where({
              :employer_id => employer.id,
              :start_date => { "$lte" => coverage_start }
            }).order_by(&:start_date).last.start_date.year
          else
            plan_year = coverage_start.year
          end
          plan = @import_cache.lookup_plan(policy_loop.hios_id, plan_year)
        else
          eg_id = policy_loop.eg_id
          hios = policy_loop.hios_id
          plan = Maybe.new(Policy.find_for_group_and_hios(eg_id, hios)).plan.value
        end

        policy = nil

        if etf.is_shop? && is_carrier_maintenance?(etf, edi_transmission)
          policy = Policy.find_by_subkeys(policy_loop.eg_id, carrier._id, policy_loop.hios_id)

          if policy
            edi_transmission.save!
          end
        else
          responsible_party_id = persist_responsible_party_get_id(etf_loop)
          broker_id = persist_broker_get_id(etf_loop)

          if(plan)
            policy = persist_policy(etf, carrier._id, plan._id, policy_loop.eg_id, employer_id, responsible_party_id, broker_id)

            if policy
              edi_transmission.save!

              persist_people(etf_loop, employer_id)
              #              Etf::FamilyParser.new(etf.people).persist!
            end
          end
        end

        #persist transaction
        policy_id = (policy.nil?) ? nil : policy._id
        persist_edi_transactions(etf_loop, policy_id, carrier._id, employer_id, edi_transmission)
      end

      # FIXME: pull sep reason
      def persist_policy(etf, carrier_id, plan_id, eg_id, employer_id, rp_id, broker_id)
        reporting_categories = etf.subscriber_loop.reporting_catergories
        existing_policy = Policy.where(hbx_enrollment_ids: eg_id).first
        new_policy = Policy.new(
          :plan_id => plan_id,
          :enrollment_group_id => eg_id,
          :carrier_id => carrier_id,
          :tot_res_amt => reporting_categories.tot_res_amt,
          :pre_amt_tot => reporting_categories.pre_amt_tot,
          :applied_aptc => reporting_categories.applied_aptc,
          :tot_emp_res_amt => reporting_categories.tot_emp_res_amt,
          :carrier_to_bill => reporting_categories.carrier_to_bill?,
          :employer_id => employer_id,
          :broker_id => broker_id,
          :responsible_party_id => rp_id,
          :enrollees => []
        )
        Policy.update_or_create_policy_from_edi(
          existing_policy,
          new_policy,
          self,
          etf,
          transaction_set_kind(etf)
        )
      end

      def build_enrollee(person, policy)
        Enrollee.new(
          :m_id => person.member_id,
          :pre_amt => person.reporting_catergories.pre_amt,
          :c_id => person.carrier_member_id,
          :cp_id => policy.id,
          :coverage_start => policy.coverage_start,
          :coverage_end => policy.coverage_end,
          :ben_stat => map_benefit_status_code(person.ben_stat),
          :rel_code => map_relationship_code(person.rel_code),
          :emp_stat => map_employment_status_code(person.emp_stat, policy.action)
        )
      end

      def persist_responsible_party_get_id(etf_loop)
        rp_loop = responsible_party_loop(etf_loop["L2000s"])
        return(nil) if rp_loop.blank?
        Etf::ResponsiblePartyParser.parse_persist_and_return_id(rp_loop)
      end

      def responsible_party_loop(all_l2000s)
        l2100Fs = all_l2000s.map { |l| l["L2100F"] }.compact
        l2100Gs = all_l2000s.map { |l| l["L2100G"] }.compact
        rp_loops = l2100Fs + l2100Gs
        rp_loops.first
      end

      def persist_broker_get_id(etf_loop)
        broker_loop = Etf::BrokerLoop.new(etf_loop["L1000C"])
        return nil if !broker_loop.valid?

        new_broker = Broker.new(
          :name_full => broker_loop.name,
          :npn => broker_loop.npn,
          :b_type => "broker"
        )
        broker = Broker.find_or_create_without_merge(new_broker)
        broker._id
      end

      def persist_employer(employer_loop, carrier_id)
        employer = nil

        if employer_loop.specified_as_group?
          employer = Employer.find_for_carrier_and_group_id(carrier_id, employer_loop.group_id)
        end
        if employer.blank?
          new_employer = Employer.new(
            :name => employer_loop.name,
            :fein => employer_loop.fein
          )
          employer = Employer.find_or_create_employer_by_fein(new_employer)
        end

        employer
      end

      def persist_people(etf_loop, employer_id)
        etf_loop["L2000s"].each do |l2000|
          Etf::PersonParser.parse_and_persist(l2000, employer_id)
        end
      end

      def create_etf_validator(etf_loop, carrier)
        etf = Etf::EtfLoop.new(etf_loop)
        EtfValidation.new(
          @file_name,
          transaction_set_kind(etf),
          etf_loop,
          carrier,
          @bgn_blacklist,
          @import_cache
        )
      end

      def run_import(l834, inbound, edi_transmission)
          #puts l834["BGN"][2]
          if !l834["ST"][3].to_s.strip.blank?
            etf_l = Etf::EtfLoop.new(l834)
            carrier = @import_cache.lookup_carrier_fein(etf_l.carrier_fein)
            carrier ||= @carrier
            etf_checker = create_etf_validator(l834, carrier)
            if !etf_checker.valid?
              persist_edi_transactions(
                l834,
                nil,
                nil,
                nil,
                edi_transmission,
                etf_checker.errors.full_messages
              )
              return
            end

            if inbound
              etf = Etf::EtfLoop.new(l834)
              incoming = IncomingTransaction.from_etf(etf, @import_cache)
              incoming.import
              persist_edi_transactions(
                l834,
                incoming.policy_id,
                incoming.carrier_id,
                incoming.employer_id,
                edi_transmission,
                incoming.errors
              )
            else
              persist_834(l834, edi_transmission)
            end
          end
        end

        def self.init_imports
          @@run_records = []
        end

        def self.run_imports
          sorted_recs = @@run_records.sort_by do |rec|
            [rec[0], rec[1], rec[2]]
          end
          sorted_recs.each do |rec|
            rec.last.call
          end
        end

        def self.add_for_import(bgn03, bgn04, bgn02, blk)
          @@run_records << [bgn03, bgn04, bgn02, blk]
        end

        def is_missing_transmission_headers?(l834)
          if l834["BGN"].blank?
            puts "Transaction Missing BGN segment:"
            puts l834.inspect
            return true
          end
          if l834["ST"].blank?
            puts "Transaction Missing ST segment:"
            puts l834.inspect
            return true
          end
          false
        end

        def persist!
          return(nil) if incomplete_isa?
          return(nil) if transmission_already_exists?
          edi_transmission = parse_edi_transmission(@result)
          return(nil) if @result["L834s"].first.blank?
          @result["L834s"].each do |l834|
            if !is_missing_transmission_headers?(l834)
            Parsers::Edi::TransmissionFile.add_for_import(
              l834["BGN"][3], 
              l834["BGN"][4], 
              l834["BGN"][2], 
              Proc.new {
              run_import(l834, @inbound, edi_transmission)
            })
            end
          end
        end

        private

        def map_employment_status_code(es_code, p_action)
          return("terminated") if p_action == :stop
          employment_status_codes = {
            "AC" => "active",
            "FT" => "full-time",
            "RT" => "retired",
            "PT" => "part-time",
            "TE" => "terminated"
          }
          result = employment_status_codes[es_code]
          result.nil? ? "active" : result
        end

        def map_relationship_code(r_code)
          relationship_codes = {
            "18" => "self",
            "01" => "spouse",
            "19" => "child",
            "15" => "ward",
            "53" => "life partner",
          }
          result = relationship_codes[r_code]
          result.nil? ? "child" : result
        end

        def map_benefit_status_code(b_code)
          benefit_codes = {
            "C" => "cobra",
            "T" => "tefra",
            "S" => "surviving insured",
            "A" => "active"
          }
          result = benefit_codes[b_code]
          result.nil? ? "active" : result
        end

        def is_carrier_maintenance?(etf, edi_transmission)
          val = ((edi_transmission.isa06.strip != ExchangeInformation.receiver_id)  &&
                 (transaction_set_kind(etf) == "maintenance"))
          val
        end

        def incomplete_isa?
          return(true) if @result["ISA"].blank?
          @result["ISA"].length < 15
        end

        def transmission_already_exists?
          Protocols::X12::Transmission.where({
            :file_name => @file_name
          }).any?
        end
      end
    end
  end
