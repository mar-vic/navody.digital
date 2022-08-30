class Apps::OrSrApp::StakeholdersIdentifiersController < ApplicationController
  rescue_from OrSrRecordFetcher::OrsrRecordError, :with => :or_sr_error
  rescue_from UpvsSubmissions::Forms::FuzsData::FuzsError, :with => :fuzs_error

  def subject_selection
  end

  def stakeholder_identifier
    if params.dig(:apps_or_sr_app_stakeholders_identifiers_application_form, :current_stakeholder_index)
      load_application_form
      update_stakeholder_identifier if params.dig(:apps_or_sr_app_stakeholders_identifiers_application_form, :stakeholder_identifier)
    else
      load_data
    end

    next_step
  end

  def stakeholders_summary
  end

  def generate_xml_form
    load_application_form
    binding.pry
  end

  def unsupported
  end

  def nothing_missing
  end

  private

  def load_data
    cin = params.require(:cin)
    form_data = UpvsSubmissions::Forms::FuzsData.new(cin: cin)

    render :unsupported and return unless form_data.sro?
    render :nothing_missing and return if form_data.all_stakeholders_ok?

    @application_form = Apps::OrSrApp::StakeholdersIdentifiers::ApplicationForm.new(form_data: form_data)
  end

  def load_application_form
    form_parameters = form_params

    @application_form = Apps::OrSrApp::StakeholdersIdentifiers::ApplicationForm.new(
      json_form_data: form_parameters['json_form_data'],
      current_stakeholder_index: form_parameters['current_stakeholder_index'].to_i,
      current_step: form_parameters['current_step'],
      go_to_summary: form_parameters['go_to_summary'],
      back: form_parameters['back']
    )
  end

  def update_stakeholder_identifier
    current_stakeholder&.identifier = param_value(:stakeholder_identifier).presence
    current_stakeholder&.set_if_foreign(nationality: param_value(:stakeholder_nationality))
    current_stakeholder&.other_identifier = param_value(:stakeholder_other_identifier).presence
    current_stakeholder&.other_identifier_type = param_value(:stakeholder_identifier_type)
    current_stakeholder&.set_date_of_birth(
      year: param_value(:stakeholder_dob_year),
      month: param_value(:stakeholder_dob_month),
      day: param_value(:stakeholder_dob_day)
    )
  end

  def next_step
    if @application_form.go_back?
      case @application_form.current_step
      when 'save'
        if @application_form.current_stakeholder_index > 0
          @application_form.current_stakeholder_index -= 1
          @application_form.stakeholder = current_stakeholder
          render :stakeholder_identifier and return
        else
          render :subject_selection and return
        end
      when 'edit'
        show_summary
      when 'summary'
        @application_form.stakeholder = current_stakeholder
        render :stakeholder_identifier and return
      when 'xml'
        show_summary
      end
    elsif should_show_summary?
      show_summary
    else
      @application_form.current_stakeholder_index += 1
      @application_form.stakeholder = current_stakeholder
    end
  end

  def show_summary
    @stakeholders = @application_form.form_data&.stakeholders_with_missing_identifiers
    render :stakeholders_summary
  end

  def form_params
    params.require(:apps_or_sr_app_stakeholders_identifiers_application_form).permit(
      :json_form_data,
      :stakeholder_identifier,
      :stakeholder_nationality,
      :stakeholder_other_identifier,
      :stakeholder_identifier_type,
      :stakeholder_dob_year,
      :stakeholder_dob_month,
      :stakeholder_dob_day,
      :current_stakeholder_index,
      :current_step,
      :go_to_summary,
      :back
    )
  end

  def current_stakeholder
    @application_form.form_data&.stakeholders_with_missing_identifiers[@application_form.current_stakeholder_index]
  end

  def should_show_summary?
    @application_form.should_go_to_summary?
  end

  def param_value(attribute)
    params[:apps_or_sr_app_stakeholders_identifiers_application_form][attribute]
  end

  def or_sr_error
    render :unsupported
  end

  def fuzs_error
    render :unsupported
  end
end
