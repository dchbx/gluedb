module Generators::Reports  
  class IrsYearlyPdfReport < PdfReport
    include ActionView::Helpers::NumberHelper

    attr_accessor :responsible_party_data, :settings, :calender_year

    def initialize(notice, options={})
      @hbx_id = notice.subscriber_hbx_id
      @settings = YAML.load(File.read("#{Rails.root}/config/irs_settings.yml")).with_indifferent_access
      initialize_variables(options)

      super({:template => get_template(options), :margin => [30, 55]})
      font_size 11

      @notice = notice
      @margin = [30, 70]
    end

    def get_template(options)
      notice_type = (['new', 'corrected'].include?(options[:notice_type]) ? 'new' : options[:notice_type])

      template_name = if (options[:calender_year] >= 2016 && options[:notice_type] != 'void')
        settings[:tax_document][options[:calender_year]][notice_type][:template][options[:qhp_type]]
      elsif (options[:calender_year] >= 2017 && options[:notice_type] == 'void')
        settings[:tax_document][options[:calender_year]][notice_type][:template][options[:void_type]]
      else
        settings[:tax_document][options[:calender_year]][notice_type][:template]
      end

      "#{Rails.root}/lib/pdf_templates/#{template_name}"
    end

    def initialize_variables(options)
      @qhp_type = options[:qhp_type]
      @calender_year = options[:calender_year]
      @multiple = options[:multiple]
      @corrected = options[:notice_type] == 'corrected'

      settings[:tax_document].keys.each do |year|
        instance_variable_set("@notice_#{year}", false)
        instance_variable_set("@void_#{year}", false)
      end

      if ['new', 'corrected'].include?(options[:notice_type])
        instance_variable_set("@notice_#{options[:calender_year]}", true)
      end

      if options[:notice_type] == 'void'
        @void = true
        instance_variable_set("@void_#{options[:calender_year]}", true)
      end

      @catastrophic = false
      @catastrophic_corrected = false
      @catastrophic_aptc = false
      @catastrophic_confirmation =  false
    end

    def process
      fill_envelope
      fill_coverletter
      fill_hbx_id_for_coverletter if @calender_year >= 2017
      return if @catastrophic_confirmation
      if @catastrophic_corrected
        go_to_page(3)
      elsif (@notice_2016 || (@void && @calender_year >= 2016))
        go_to_page(9)
      elsif @calender_year >= 2017
        go_to_page(11)
      else
        go_to_page(5)
      end
      fill_subscriber_details
      fill_household_details unless (@void_2014 || @void_2016)
      fill_preimum_details
    end

    def fill_envelope
      if @calender_year >= 2017
        x_pos = mm2pt(14.00) - @margin[0]
        y_pos = 790.86 - mm2pt(44.00) - 65
        bounding_box([x_pos, y_pos], :width => 300) do
          open_sans_font
          fill_recipient_contact(10)
        end
      else
        x_pos = mm2pt(21.83) - @margin[0]
        y_pos = 790.86 - mm2pt(57.15) - 65
        bounding_box([x_pos, y_pos], :width => 300) do
          fill_recipient_contact(10)
        end
      end
    end

    def print_policies(policies_array, x_ps, y_ps)
      rows = 5
      @y_ps = y_ps
      policies_count = policies_array.count
      offset = 0

      while(offset <= policies_count)
        policies_array[offset, rows].each do |policy|
          bounding_box([x_ps, y_ps], :width => 200) do
            open_sans_font
            text "•   " +  policy
          end
          y_ps = y_ps - 12
        end
        y_ps = @y_ps
        x_ps = x_ps + 85
        offset = offset + rows
      end
    end

    def fill_coverletter
      go_to_page(settings[:tax_document][calender_year][:coverage_page_no])

      padding = 31
      padding = 10

      padding = 26 if @void_2014 || @void_2016

      #For Printing Date on template
      if @calender_year == 2017
        bounding_box([17, 445+padding], :width => 200) do
          open_sans_font
          text "#{Date.today.strftime('%m/%d/%Y')}", size: 10
        end
      elsif @calender_year >= 2018
        bounding_box([8.5, 508+padding], :width => 200) do
          open_sans_font
          text "#{Date.today.strftime('%m/%d/%Y')}", size: 10
        end
      else
        bounding_box([15, 553+padding], :width => 200) do
          text "#{Date.today.strftime('%m/%d/%Y')}"
        end
      end

      #For Printing Address on template
      if @calender_year >= 2017
        bounding_box([8, 590+padding], :width => 300) do
          open_sans_font
          fill_recipient_contact(10)
        end
      else
        bounding_box([15, 525+padding], :width => 300) do
          fill_recipient_contact
        end
      end

      y_pos = if @catastrophic
        405
      elsif @catastrophic_corrected
        444
      else
        if @notice_2014 # 2014
          418
        else
          # 430 # 2014 void
          430 # 2015
        end
      end

      x_pos = 44

      x_pos = 42 if @catastrophic_corrected

      padding = 12 unless @void_2014
      padding = 20 if @void_2016
      y_pos = 409 if @void_2016
      y_pos = 444 if @void_2015

      #For Printing Receipent Name on template for 2017
      if @calender_year == 2017
        bounding_box([42, 375.75+padding], :width => 200) do
          open_sans_font
          text "#{@notice.recipient.name}:", size: 10
        end
      elsif @calender_year >= 2018
        bounding_box([36, 447.6+padding], :width => 200) do
          open_sans_font
          text "#{@notice.recipient.name_first}:", size: 10
        end
      else
        bounding_box([x_pos, y_pos+padding], :width => 200) do
          text "#{@notice.recipient.name}:"
        end
      end

      padding = -20 if @void_2016

      if @void && @calender_year >= 2018
        set_positions(340, padding)
      elsif @void_2017
        set_positions(285, padding)
      end

      if @void_2016
        bounding_box([93, 242+padding], :width => 200) do
          text @notice.canceled_policies.blank? ? 'None' : @notice.canceled_policies
        end

        bounding_box([100, 132+padding], :width => 200) do
          text @notice.active_policies.blank? ? 'None' : @notice.active_policies
        end
      end

      if @void_2015
        bounding_box([133, 237+padding], :width => 200) do
          text @notice.canceled_policies.blank? ? 'None' : @notice.canceled_policies
        end

        bounding_box([120, 141+padding], :width => 200) do
          text @notice.active_policies.blank? ? 'None' : @notice.active_policies
        end
      end

      if @void_2014
        bounding_box([133, 292+padding], :width => 200) do
          text @notice.canceled_policies.blank? ? 'None' : @notice.canceled_policies
        end

        bounding_box([120, 223+padding], :width => 200) do
          text @notice.active_policies.blank? ? 'None' : @notice.active_policies
        end
      end
    end

    def fill_hbx_id_for_coverletter
      if @calender_year >= 2018 && !@void
        pages = [4, 5]
      elsif @qhp_type.present? && (!@void || (@void && @calender_year <= 2016))
        pages = [4, 5, 6]
      elsif @void && @calender_year >= 2017
        pages = [4]
      end

      pages.each do |page|
        go_to_page(page)
        if @calender_year >= 2018
          bounding_box([405, 753], :width => 200) do
            open_sans_font
            text "#{@hbx_id}", size: 8
          end
        else
          bounding_box([400, 739.2], :width => 200) do
            open_sans_font
            text "#{@hbx_id}", size: 8
          end
        end
      end
    end

    def open_sans_font
      font "#{Rails.root.join("app/assets/fonts/Open_Sans/OpenSans-Regular.ttf")}"
    end

    def fill_recipient_contact(font_size=nil)
      font_size = 11 if font_size.nil?
      text @notice.recipient.name, size: font_size
      text @notice.recipient_address.street_1, size: font_size
      text @notice.recipient_address.street_2, size: font_size unless @notice.recipient_address.street_2.blank?
      text "#{@notice.recipient_address.city}, #{@notice.recipient_address.state} #{@notice.recipient_address.zip}", size: font_size
    end

    def fill_subscriber_details
      col1 = mm2pt(-2)
      col2 = mm2pt(51.50)
      col3 = mm2pt(102.50)
      col4 = mm2pt(145.50)
      y_pos = 790.86 - mm2pt(37.15) - 45

      x_pos_corrected = mm2pt(128.50)
      y_pos_corrected = 790.86 - mm2pt(31.80)
      y_pos_corrected = 790.86 - mm2pt(23.80) if @void && @calender_year >= 2015

      if @corrected || @void
        bounding_box([x_pos_corrected, y_pos_corrected], :width => 100) do
          text "x"
        end
      end

      font "Times-Roman"

      bounding_box([col1, y_pos], :width => 100) do
        text 'DC'
      end


      if !@void_2014
        bounding_box([col2, y_pos], :width => 150) do
          text @notice.policy_id
        end

        bounding_box([col3, y_pos], :width => 200) do
          text @notice.issuer_name
        end
      end

      move_down(12)
      if @notice.recipient.blank?
        raise "no subscriber!!"
      end

      fill_enrollee(@notice.recipient, @responsible_party_data)

      move_down(12)
      if @notice.spouse && @notice.has_aptc && !@void_2014
        fill_enrollee(@notice.spouse)
      else
        move_down(13)
      end
      move_down(11)
      y_pos = cursor
      bounding_box([col1, y_pos], :width => 100) do
        text @notice.recipient.coverage_start_date unless @void_2014
      end

      bounding_box([col2, y_pos], :width => 100) do
        text @notice.recipient.coverage_termination_date.to_s unless @void_2014
      end

      bounding_box([col3, y_pos], :width => 250) do
        street_address = @notice.recipient_address.street_1
        if !@notice.recipient_address.street_2.blank?
          street_address += ", #{@notice.recipient_address.street_2}"
        end
        text street_address
      end

      move_down(12)
      y_pos = cursor
      bounding_box([col1, y_pos], :width => 120) do
        text @notice.recipient_address.city
      end

      bounding_box([col2, y_pos], :width => 100) do
        text @notice.recipient_address.state
      end

      bounding_box([col3, y_pos], :width => 100) do
        text @notice.recipient_address.zip
      end
    end

    def fill_enrollee(enrollee, responsible_party_data = {})
      col1 = mm2pt(-2)
      col3 = mm2pt(102.50)
      col4 = mm2pt(145.50)
      y_pos = cursor

      bounding_box([col1, y_pos], :width => 240) do
        text enrollee.name
      end
      
      enrollee_ssn = responsible_party_data.blank? ? enrollee.ssn : responsible_party_data[0]

      if !enrollee_ssn.blank?
        bounding_box([col3, y_pos], :width => 100) do
          text mask_ssn(enrollee_ssn)
        end
      else
        enrollee_dob = responsible_party_data.blank? ? enrollee.dob : responsible_party_data[1].strftime("%m/%d/%Y")
        bounding_box([col4, y_pos], :width => 100) do
          text enrollee_dob || ''
        end
      end
    end

    def fill_household_details
      col1 = mm2pt(0)
      col2 = mm2pt(67.50)
      col3 = mm2pt(98.50)
      col4 = mm2pt(128.50)
      col5 = mm2pt(159.50)

      y_pos = 472

      covered_household = @notice.covered_household[0..4]
      covered_household = @notice.covered_household[5..9] if @multiple

      covered_household.each do |individual|
        bounding_box([col1, y_pos], :width => 150) do
          text individual.name
        end
        if !individual.ssn.blank?
          bounding_box([col2, y_pos], :width => 100) do
            text mask_ssn(individual.ssn)
          end
        else
          bounding_box([col3, y_pos], :width => 100) do
            text individual.dob
          end
        end
        bounding_box([col4, y_pos], :width => 100) do
          text individual.coverage_start_date
        end
        bounding_box([col5, y_pos], :width => 100) do
          text individual.coverage_termination_date
        end
        y_pos = y_pos - 24
      end      
    end

    def fill_preimum_details
      col1 = mm2pt(36.50)
      col2 = mm2pt(76.50)
      col3 = mm2pt(125.50)
      y_pos = 304
      
      (1..12).each do |index|
        monthly_premium = @notice.monthly_premiums.detect{|p| p.serial == index}
        monthly_premium = nil if monthly_premium.present? && monthly_premium.premium_amount.nil?

        if monthly_premium || @void_2014
          bounding_box([col1, y_pos], :width => 100) do
            text number_to_currency((@void_2014 || @catastrophic_corrected) ? 0.0 : monthly_premium.premium_amount), :align => :right
          end

          if @void_2014 || (monthly_premium.monthly_aptc.present? && monthly_premium.monthly_aptc.to_f > 0)
            bounding_box([col2, y_pos], :width => 130) do
              text number_to_currency((@void_2014 || @catastrophic_corrected) ? 0.0 : monthly_premium.premium_amount_slcsp), :align => :right
            end

            bounding_box([col3, y_pos], :width => 120) do
              text number_to_currency(@void_2014 ? 0.0 : monthly_premium.monthly_aptc), :align => :right
            end
          end
        end
        y_pos = y_pos - 24
      end

      bounding_box([col1, y_pos], :width => 100) do
        text number_to_currency((@void_2014 || @catastrophic_corrected) ? 0.0 : @notice.yearly_premium.premium_amount), :align => :right
      end

      if @void_2014 || @notice.yearly_premium.aptc_amount.present?
        bounding_box([col2, y_pos], :width => 130) do
          text number_to_currency((@void_2014 || @catastrophic_corrected) ? 0.0 : @notice.yearly_premium.slcsp_premium_amount), :align => :right
        end
  
        bounding_box([col3, y_pos], :width => 120) do
          text number_to_currency(@void_2014 ? 0.0 : @notice.yearly_premium.aptc_amount), :align => :right
        end
      end
    end

    def number_to_ssn(number)
      number.gsub!('-','')
      delimiter = "-"
      number.to_s.gsub!(/(\d{0,3})(\d{2})(\d{4})$/,"\\1#{delimiter}\\2#{delimiter}\\3")
    end

    def mask_ssn(ssn)
      return if ssn.blank?
      ssn = number_to_ssn(ssn)
      last_digits = ssn.match(/\d{4}$/)[0]
      "***-**-#{last_digits}"
    end

    def set_positions(y_position, padding)
      canceled_policies = @notice.canceled_policies.split(',')
      print_policies(canceled_policies, 18, y_position+padding)
      if @notice.active_policies.present?
        active_policies = @notice.active_policies.split(',')
        y_ps = (@void && @calender_year >= 2019) ? 125+padding : 130+padding
        print_policies(active_policies, 18, y_ps)
      end
    end
  end
end