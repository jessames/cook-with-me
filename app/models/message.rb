class Message < ApplicationRecord
  belongs_to :cook_session
  belongs_to :instruction
end
