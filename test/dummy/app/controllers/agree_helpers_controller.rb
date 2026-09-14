# frozen_string_literal: true

class AgreeHelpersController < ApplicationController
  def show
  end

  def create
    root = current_root_recordable
    terms = RecordingStudioTermsAndConditions.current_published_for(root)
    unless ActiveModel::Type::Boolean.new.cast(params[:agreed])
      flash.now[:alert] = "Tick the box if you agree."
      render :show, status: :unprocessable_entity
      return
    end
    if terms.blank?
      redirect_to "/agree_helper", alert: "There are no live terms to agree to."
      return
    end

    unless RecordingStudioTermsAndConditions.accepted?(current_user, root)
      RecordingStudioTermsAndConditions.accept!(current_user, terms, { "source" => "clickwrap" })
    end

    redirect_to "/agree_helper", notice: "You're in. Thanks for reading."
  end
end
