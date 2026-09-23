# frozen_string_literal: true

class AgreeHelpersController < ApplicationController
  def show
  end

  def create
    pending = RecordingStudioTermsAndConditions.pending_published_list(current_user, current_root_recordable)
    if pending.blank?
      redirect_to agree_helper_path, alert: "There are no live terms to agree to."
      return
    end

    source = acceptance_source
    if source == "clickwrap" && !agreed?
      redirect_to agree_helper_path, alert: "Tick the box if you agree."
      return
    end

    pending.each do |terms|
      RecordingStudioTermsAndConditions.accept!(current_user, terms, { "source" => source })
    end
    redirect_to root_path
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
