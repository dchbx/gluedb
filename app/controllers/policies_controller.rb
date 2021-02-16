class PoliciesController < ApplicationController
  load_and_authorize_resource
  rescue_from EndCoverage::PremiumCalcError, with: :redirect_back_with_message

  def new
    @form = PolicyForm.new(family_id: params[:family_id], household_id: params[:household_id])
  end

  def show
    @policy = Policy.find(params[:id])
    respond_to do |format|
      format.xml
    end
  end

  def create
    request = CreatePolicyRequestFactory.from_form(params[:policy_form])
    raise request.inspect

    CreatePolicy.new.execute(request)
    redirect_to families_path
  end

  def edit
    @policy = Policy.find(params[:id])

    @policy.enrollees.each { |e| e.include_checked = true }

    people_not_on_plan = @policy.household.people.reject { |p| p.policies.include?(@policy)}
    people_not_on_plan.each do |person|
      @policy.enrollees << Enrollee.new(m_id: person.authority_member_id)
    end
  end

  def update
    raise params.inspect
  end

  def cancelterminate
    @cancel_terminate = CancelTerminate.new(params)
  end

  def transmit
    @cancel_terminate = CancelTerminate.new(params)

    if @cancel_terminate.valid?
      request = EndCoverageRequest.from_form(params, current_user.email)
      EndCoverage.new(EndCoverageAction).execute(request)
      redirect_to person_path(Policy.find(params[:id]).subscriber.person)
    else
      @cancel_terminate.errors.full_messages.each do |msg|
        flash_message(:error, msg)
      end
      render :cancelterminate
    end

  end

  def change_npt_indicator
    altered_npt_indicator = params[:policy][:npt_indicator]
    policy = Policy.find(params[:policy][:id])
    message = Policy.change_npt_indicator(policy, altered_npt_indicator, current_user.email)
    redirect_to cancelterminate_policy_path({ :id => params[:policy][:id]}), flash: message
  end

  def index
    @q = params[:q]
    @qf = params[:qf]
    @qd = params[:qd]

    if params[:q].present?
      @policies = Policy.search(@q, @qf, @qd).page(params[:page]).per(15)
    else
      @policies = Policy.page(params[:page]).per(15)
    end

    respond_to do |format|
	    format.html # index.html.erb
	    format.json { render json: @policies }
	  end
  end

  def generate_tax_document
    @policy = Policy.find(params[:id])
    @person = Person.find(params[:person_id])

    tax_doc_params = {policy_id: params[:id],
                      type:params[:type],
                      void_active_policy_ids: void_policy_ids(params[:void_active_policy_ids]),
                      void_cancelled_policy_ids: void_policy_ids(params[:void_cancelled_policy_ids]),
                      npt: params[:npt] == "1" ? true : false}
    if @policy.has_responsible_person?
      if params[:responsible_person_ssn].present?
        tax_doc_params[:responsible_party_ssn] = params[:responsible_person_ssn]
      end

      if params[:responsible_person_dob].present?
        tax_doc_params[:responsible_party_dob] = Date.strptime(params[:responsible_person_dob], "%m/%d/%Y")
      end
    end

    @file_name = generate_1095A_pdf(tax_doc_params)  #call doc generation service

    if params[:preview] != "1"
      begin
        if upload_to_s3(@file_name, "tax-documents")
          delete_1095A_pdf(@file_name)
          redirect_to person_path(@person), :flash => { :notice=> "1095A PDF queued for upload and storage." }
          return
        else
          raise("File upload failed")
        end
      rescue Exception => e
          redirect_to person_path(@person), :flash => { :error=> "Could not upload file. #{e.message}" }
      end
    end
  end

  def download_tax_document
    if params[:file_name].blank?
      redirect_to generate_tax_document_form_policy_path(Policy.find(params[:id]), {person_id: Person.find(params[:person_id])}), :flash => { :error=> "Could not generate preview. No file name present in URL. Please try again." }
      return
    end
    send_file(params[:file_name], :type => 'application/pdf', :disposition => 'inline')
  end

  def upload_tax_document_to_S3
    if params[:file_name].blank?
      redirect_to generate_tax_document_form_policy_path(Policy.find(params[:id]), {person_id: Person.find(params[:person_id])}), :flash => { :error=> "Could not upload document. Request missing essential parameter. Please try again." }
      return
    end

    person = Person.find(params[:person_id])

    begin
      if upload_to_s3(params[:file_name], "tax-documents")
        delete_1095A_pdf(params[:file_name])
        redirect_to person_path(person), :flash => { :notice=> "1095A PDF queued for upload and storage." }
        return
      else
        raise("File upload failed.")
      end
    rescue Exception => e
      redirect_to person_path(person), :flash => { :error=> "Could not upload file. #{e.message}" }
    end
  end

  def generate_tax_document_form
    @policy = Policy.find(params[:id])
    @person = Person.find(params[:person_id])
  end

  def delete_local_generated_tax_document
    person = Person.find(params[:person_id])

    if params[:file_name].blank?
      redirect_to person_path(person), :flash => { :notice=> "Could not delete 1095A PDF. Request parameter missing." }
      return
    end

    begin
      if delete_1095A_pdf(params[:file_name])
        redirect_to person_path(person), :flash => { :notice=> "Deleted the generated 1095A PDF." }
        return
      else
        raise
      end
    rescue Exception => e
      redirect_to person_path(person), :flash => { :error=> "Could not delete 1095A PDF #{e.message}" }
    end
  end

  private

  def void_policy_ids(policy_ids_string)
    return [] if policy_ids_string.blank?
    policy_ids_string.gsub(" ", "").split(",").compact
  end

  def upload_to_s3(file_name, bucket_name)
    Aws::S3Storage.save(file_name, bucket_name, File.basename(file_name))
  end

  def delete_1095A_pdf(file_name)
    File.delete(file_name)
  end

  def generate_1095A_pdf(params)
    params[:type] = 'new' if params[:type] == 'original'
    Generators::Reports::IrsYearlySerializer.new(params).generate_notice
  end
end
