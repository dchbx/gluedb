class PaymentProcessorUploadsController < VocabUploadsController
  load_and_authorize_resource :class => "PaymentProcessorUpload"

  def new
    @payment_processor_vocab_upload = PaymentProcessorUpload.new(:submitted_by => current_user.email)
  end

  def create
    @payment_processor_vocab_upload = PaymentProcessorUpload.new(params[:payment_processor_upload])

    if @payment_processor_vocab_upload.save(self)
      flash_message(:success, "\"#{params[:payment_processor_upload][:vocab].original_filename}\" - Uploaded successfully.")
      redirect_to new_payment_processor_upload_path
    else
      flash_message_now(:error, "\"#{params[:payment_processor_upload][:vocab].original_filename}\" - Failed to Upload.") if params[:payment_processor_upload][:vocab]
      flash_message_now(:error, "Please select \"Initial enrollment\" or \"Maintenance\"") unless params[:payment_processor_upload][:kind].present?
      render :new
    end
  end

  def enrollment_not_shop_market(details)
    flash_message_now(:error, "Expected enrollment market type is shop but got #{details[:provided]}")
  end
end
