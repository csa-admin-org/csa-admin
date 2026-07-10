# frozen_string_literal: true

ActiveAdmin.register BankConnection do
  menu false
  actions :new, :create
  config.clear_action_items!
  config.filters = false

  breadcrumb do
    [ link_to(BankConnection.model_name.human(count: 2), organization_path(anchor: "bank_connection")) ]
  end

  form as: :ebics_setup, html: { novalidate: true, data: { turbo: false } } do |f|
    f.inputs t("active_admin.resources.bank_connection.ebics_setup.instructions_title"), icon: "book-open" do
      li class: "panel-actions" do
        text_node handbook_icon_link("billing", anchor: "automatic_payments_processing")
      end

      li class: "space-y-5 px-2 pb-2 text-base leading-7 text-gray-950 dark:text-gray-100" do
        para sanitize(
          t("active_admin.resources.bank_connection.ebics_setup.intro_html", support_url: support_path),
          tags: %w[a],
          attributes: %w[href]
        ), class: "m-0"

        para sanitize(
          t("active_admin.resources.bank_connection.ebics_setup.return_html", support_url: support_path),
          tags: %w[a],
          attributes: %w[href]
        ), class: "m-0 pt-2"

        div class: "pt-2" do
          h4 t("active_admin.resources.bank_connection.ebics_setup.bank_access_title"),
            class: "mb-2 mt-4 font-semibold"

          ul class: "list-disc space-y-1 pl-5" do
            li t("active_admin.resources.bank_connection.ebics_setup.bank_access.ebics")
            if Current.org.country_code == "CH"
              li t("active_admin.resources.bank_connection.ebics_setup.bank_access.payment_reports_ch")
            else
              li t("active_admin.resources.bank_connection.ebics_setup.bank_access.payment_reports_de")
              li t("active_admin.resources.bank_connection.ebics_setup.bank_access.direct_debit_de")
            end
          end
        end

        if Current.org.country_code == "CH"
          para sanitize(
            t(
              "active_admin.resources.bank_connection.ebics_setup.bas_html",
              handbook_url: handbook_page_path("billing", anchor: "abs-setup"),
              support_url: support_path),
            tags: %w[a],
            attributes: %w[href]
          ), class: "m-0 pt-2 italic text-gray-600 dark:text-gray-400"
        end

        if Tenant.demo?
          para t("active_admin.resources.bank_connection.ebics_setup.demo_disabled"),
            class: "mt-4 rounded-md bg-yellow-100 p-3 text-sm text-yellow-900 ring-1 ring-yellow-600/25 ring-inset dark:bg-yellow-950 dark:text-yellow-300 dark:ring-yellow-400/25"
        end
      end
    end

    f.inputs t("active_admin.resources.bank_connection.ebics_setup.form_title"), icon: "notebook-text" do
      f.semantic_errors :base

      f.input :url,
        label: t("active_admin.resources.bank_connection.ebics_setup.fields.url"),
        hint: t("active_admin.resources.bank_connection.ebics_setup.hints.url_html"),
        required: true,
        input_html: { disabled: Tenant.demo?, placeholder: "https://ebics.bank.example/ebics" }

      f.input :host_id,
        label: t("active_admin.resources.bank_connection.ebics_setup.fields.host_id"),
        required: true,
        input_html: { disabled: Tenant.demo? }

      f.input :client_id,
        label: t("active_admin.resources.bank_connection.ebics_setup.fields.client_id"),
        hint: sanitize(
          t("active_admin.resources.bank_connection.ebics_setup.hints.client_id_html", support_url: support_path),
          tags: %w[a],
          attributes: %w[href]
        ),
        required: true,
        input_html: { disabled: Tenant.demo? }

      f.input :participant_id,
        label: t("active_admin.resources.bank_connection.ebics_setup.fields.participant_id"),
        hint: sanitize(
          t("active_admin.resources.bank_connection.ebics_setup.hints.participant_id_html", support_url: support_path),
          tags: %w[a],
          attributes: %w[href]
        ),
        required: true,
        input_html: { disabled: Tenant.demo? }

      f.input :confirmation,
        as: :boolean,
        label: t("active_admin.resources.bank_connection.ebics_setup.fields.confirmation"),
        required: true,
        input_html: { disabled: Tenant.demo? }
    end

    f.actions do
      if Tenant.demo?
        li class: "action input_action" do
          button type: "submit", disabled: true, class: "cursor-not-allowed" do
            text_node t("active_admin.resources.bank_connection.ebics_setup.submit")
          end
        end
      else
        f.action :submit,
          label: t("active_admin.resources.bank_connection.ebics_setup.submit"),
          icon: "cable"
      end

      cancel_link organization_path(anchor: "bank_connection")
    end
  end

  controller do
    def new
      authorize! :create, BankConnection
      if blocker = setup_blocker
        redirect_to organization_path(anchor: "bank_connection"), alert: blocker
        return
      end

      build_ebics_setup
    end

    def create
      authorize! :create, BankConnection
      if blocker = setup_blocker
        redirect_to organization_path(anchor: "bank_connection"), alert: blocker
        return
      end

      build_ebics_setup(ebics_setup_params)
      if Tenant.demo?
        @ebics_setup.errors.add(:base, t("active_admin.resources.bank_connection.ebics_setup.demo_disabled"))
        render_new(status: :unprocessable_entity)
      elsif @ebics_setup.valid?
        connection = create_setup!
        notify_setup_submitted!(connection)
        redirect_to organization_path(anchor: "bank_connection"), notice: t("active_admin.resources.bank_connection.ebics_setup.flash.notice")
      else
        render_new(status: :unprocessable_entity)
      end
    rescue Billing::EBICS::UnsupportedOperation => error
      handle_ebics_setup_error(error)
    rescue ActiveRecord::ActiveRecordError
      notify_setup_support_needed!
      redirect_to organization_path(anchor: "bank_connection"), alert: t("active_admin.resources.bank_connection.ebics_setup.flash.alert")
    end

    private

    def build_ebics_setup(attributes = {})
      @page_title = t("active_admin.resources.bank_connection.ebics_setup.title")
      @ebics_setup = BankConnection::EBICSSetup.new(attributes)
      @bank_connection = @ebics_setup
    end

    def render_new(status: :ok)
      @page_title = t("active_admin.resources.bank_connection.ebics_setup.title")
      @bank_connection = @ebics_setup
      render :new, status: status
    end

    def ebics_setup_params
      params.fetch(:ebics_setup, {}).permit(:url, :host_id, :client_id, :participant_id, :confirmation)
    end

    def setup_blocker
      if Current.org.bank_connection?
        t("active_admin.resources.bank_connection.ebics_setup.flash.active_connection")
      elsif existing_ebics_setup?
        t("active_admin.resources.bank_connection.ebics_setup.flash.existing_setup")
      elsif !BankConnection::EBICSSetup.supported_country?
        t("active_admin.resources.bank_connection.ebics_setup.flash.unsupported_country")
      end
    end

    def existing_ebics_setup?
      BankConnection.where(
        provider: "ebics",
        active: false,
        state: %w[initializing waiting_for_bank errored]).exists?
    end

    def create_setup!
      settings = @ebics_setup.settings_for
      onboarding = Billing::EBICS::Onboarding.new
      onboarding.initialize_connection!(**@ebics_setup.onboarding_attributes)
      @setup_connection = onboarding.connection.reload
      record_setup_metadata!(@setup_connection, settings)

      onboarding.submit_ini!
      onboarding.submit_hia!
      @setup_connection.reload
    end

    def record_setup_metadata!(connection, settings)
      details = connection.status_details.to_h.deep_stringify_keys
      onboarding = details.fetch("onboarding") { {} }
      details["onboarding"] = onboarding.merge(
        "initiated_at" => Time.current.iso8601,
        "initiated_by_admin_id" => current_admin.id,
        "initiated_by_admin_email" => current_admin.email)

      connection.update!(settings: settings, status_details: details)
    end

    def handle_ebics_setup_error(error)
      if preflight_setup_error?(error)
        add_preflight_setup_error(error)
        render_new(status: :unprocessable_entity)
      elsif inline_setup_error?
        add_inline_setup_error
        @setup_connection.destroy!
        @setup_connection = nil
        render_new(status: :unprocessable_entity)
      else
        notify_setup_support_needed!
        redirect_to organization_path(anchor: "bank_connection"), alert: t("active_admin.resources.bank_connection.ebics_setup.flash.alert")
      end
    end

    def preflight_setup_error?(error)
      return false if @setup_connection.present?

      error.is_a?(Billing::EBICS::VersionProbe::EndpointError) ||
        error.is_a?(Billing::EBICS::VersionProbe::HostIDError) ||
        error.is_a?(Billing::EBICS::VersionProbe::UnsupportedVersionError)
    end

    def add_preflight_setup_error(error)
      if error.is_a?(Billing::EBICS::VersionProbe::HostIDError)
        @ebics_setup.add_host_id_check_error
      else
        @ebics_setup.add_endpoint_check_error
      end
    end

    def inline_setup_error?
      @setup_connection&.persisted? && setup_status["ini_submitted_at"].blank? && user_fixable_setup_error?
    end

    def user_fixable_setup_error?
      endpoint_setup_error? || bank_rejected_setup_error?
    end

    def endpoint_setup_error?
      setup_error_class.in?(%w[
        Billing::EBICS::Btf::Transport::HTTPError
        Billing::EBICS::BtfClient::InvalidResponseError
        EOFError
        Errno::ECONNREFUSED
        Errno::EHOSTUNREACH
        Errno::ENETUNREACH
        Net::OpenTimeout
        Net::ReadTimeout
        OpenSSL::SSL::SSLError
        SocketError
      ])
    end

    def bank_rejected_setup_error?
      setup_error_class.in?(%w[
        Billing::EBICS::BtfClient::ResponseError
        Billing::EBICS::ClientError
        Billing::EBICS::TechnicalError
      ])
    end

    def add_inline_setup_error
      if endpoint_setup_error?
        @ebics_setup.add_endpoint_check_error
      else
        @ebics_setup.add_identifier_check_error
      end
    end

    def setup_error_class
      @setup_connection&.last_error_class.to_s
    end

    def setup_status
      @setup_connection.status_details.to_h.dig("onboarding").to_h.deep_stringify_keys
    end

    def notify_setup_submitted!(connection)
      AdminMailer
        .with(admin: current_admin, connection: connection)
        .ebics_setup_submitted_email
        .deliver_later

      EBICSOnboardingMailer
        .with(connection: connection)
        .setup_submitted_notification_email
        .deliver_later
    end

    def notify_setup_support_needed!
      return unless @setup_connection&.persisted?

      EBICSOnboardingMailer
        .with(connection: @setup_connection.reload)
        .support_needed_notification_email
        .deliver_later
    end
  end
end
