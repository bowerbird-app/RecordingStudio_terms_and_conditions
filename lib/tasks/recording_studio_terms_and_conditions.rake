# frozen_string_literal: true

namespace :recording_studio_terms_and_conditions do
  desc "Seed sections and clauses from each Terms body. Does not publish or write receipts."
  task seed_outline: :environment do
    actor = RecordingStudioTermsAndConditions::OutlineSeedActor.resolve!
    count = RecordingStudioTermsAndConditions::Outline.seed_all!(actor: actor)
    puts "Seeded #{count} Terms documents"
  end
end
