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

    RecordingStudioTermsAndConditions.accept!(current_user, terms, { "source" => "continue_notice" })
    redirect_to root_path, notice: "You're in. Thanks for reading."
  end
end
