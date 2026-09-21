# frozen_string_literal: true

class AgreeHelpersController < ApplicationController
  def show
  end

  def create
    terms = RecordingStudioTermsAndConditions.pending_published_for(current_user, current_root_recordable)
    if terms.blank?
      redirect_to agree_helper_path, alert: "There are no live terms to agree to."
      return
    end

    source = acceptance_source
    if source == "clickwrap" && !agreed?
      redirect_to agree_helper_path, alert: "Tick the box if you agree."
      return
    end

    RecordingStudioTermsAndConditions.accept!(current_user, terms, { "source" => source })
    redirect_to root_path, notice: "You're in. Thanks for reading."
  end

  private

  def acceptance_source
    source = params[:source].to_s
    return source if %w[clickwrap continue_notice].include?(source)

    "continue_notice"
  end

  def agreed?
    ActiveModel::Type::Boolean.new.cast(params[:agreed])
  end
end
