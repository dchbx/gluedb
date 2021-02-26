class VocabUploadsController < ApplicationController
  load_and_authorize_resource :class => "VocabUpload"
  rescue_from Parsers::Xml::Enrollment::Enrollee::ShopEnrollee::BeginDateOutsidePlanYearsError, with: :redirect_back_with_message

  def new
    @vocab_upload = VocabUpload.new(:submitted_by => current_user.email)
  end

  def create
    @vocab_upload = VocabUpload.new(params[:vocab_upload])
    @vocab_upload.bypass_validation = params[:vocab_upload][:bypass_validation] == "1"

    if @vocab_upload.save(self)
      flash_message(:success, "\"#{params[:vocab_upload][:vocab].original_filename}\" - Uploaded successfully.")
      redirect_to new_vocab_upload_path
    else
      flash_message_now(:error, "\"#{params[:vocab_upload][:vocab].original_filename}\" - Failed to Upload.") if params[:vocab_upload][:vocab]
      flash_message_now(:error, "Please select \"Initial enrollment\" or \"Maintenance\"") unless params[:vocab_upload][:kind].present?
      render :new
    end
  end

  def aptc_too_large(details)
    flash_message_now(:error, "aptc value is too large. " + details_text(details))
  end

  def group_has_incorrect_responsible_amount(details)
    flash_message_now(:error, "total_responsible_amount is incorrect. " + details_text(details))
  end

  def group_has_incorrect_premium_total(details)
    flash_message_now(:error, "premium_amount_total is incorrect. " + details_text(details))
  end

  # Premium validator check has been removed
  # def enrollee_has_incorrect_premium(details)
  #   flash_message_now(:error, "#{details[:name]}'s premium_amount is incorrect. " + details_text(details))
  # end

  # def premium_not_found
  #   flash_message_now(:error, "Premium was not found in the system.")
  # end

  def details_text(details)
    "Expected $#{sprintf "%.2f", details[:expected]} but got $#{sprintf "%.2f", details[:provided]}."
  end
end
