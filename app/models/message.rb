class Message < ApplicationRecord
  belongs_to :cook_session
  belongs_to :instruction, optional: true

  validates :role, inclusion: {
    in: %w[user assistant]
  }

  validates :content, presence: true

  def proposed_change?
    proposed_change.present?
  end

  def accepted?
    accepted_at.present?
  end
end
