require File.join(Rails.root, "lib/mongoid_migration_task")
require 'nokogiri'
class FederalTransmissionReport < MongoidMigrationTask  
  def migrate
    federal_report = Generators::Reports::Importers::FederalReportIngester.new
    federal_report.federal_report_ingester
  end
end