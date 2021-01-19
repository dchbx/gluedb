module FederalReports
  class ReportUploadError < StandardError
    attr_reader :input

    def initialize(source, message)
      super(message)
      @input = source
    end
  end
end
