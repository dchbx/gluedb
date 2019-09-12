module Parsers
  module Edi
    class TransmissionResponse
      attr_reader :parser, :transmitted_at, :sender_id

      def initialize(path, payload)
        @input = payload
        @file_name = File.basename(path)
        @result = Oj.load(@input)
        parse_header
        parse_response
      end

      def parse_header
        isa_seg = @result["ISA"]
        result_date = isa_seg[9]
        result_time = isa_seg[10]
        result_dt = "20" + result_date + result_time
        @transmitted_at = DateTime.strptime("20" + result_date + result_time, "%Y%m%d%H%M")
        @sender_id = isa_seg[6].strip
      end

      def parse_response
        ta1_seg = @result["TA1s"].first
        if ta1_seg.blank?
          @has_data = false
          return nil
        end
        @accepted = ["A", "E"].include?(ta1_seg[4])
        @isa13 = ta1_seg[1]
        @isa09 = ta1_seg[2]
        @isa10 = ta1_seg[3]
        @has_data = true
      end

      def accepted?
        @accepted
      end

      def persist!
        return nil unless @has_data
        transmission = Protocols::X12::Transmission.where(
          :isa13 => @isa13,
          :isa08 => @sender_id
        ).first
        if !transmission.nil?
          if accepted?
            transmission.acknowledge!(@transmitted_at)
          else
            transmission.reject!(@transmitted_at)
          end
        end
      end
    end
  end
end
