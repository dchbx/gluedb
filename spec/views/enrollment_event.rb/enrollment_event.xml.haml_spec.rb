require 'rails_helper'
# require File.join(Rails.root, "spec", "support", "acapi_vocabulary_spec_helpers")

RSpec.describe "app/views/enrollment_events/_enrollment_event.xml.haml" do

  context "test" do

    before :each do

    end

    it "should have" do

      render :template => "enrollment_events/_enrollment_event.xml.haml", :locals => { :affected_members => '' }


    end
    end


end