require "digest"
require "json"

module ReviewedInstructionCleanup
  PLANS = JSON.parse(File.read(File.expand_path("../db/data/reviewed_instruction_edits.json", __dir__))).freeze

  def self.plan(external_id, texts)
    entry = PLANS[external_id.to_s]
    return unless entry && entry.fetch("checksum") == Digest::SHA256.hexdigest(JSON.generate(texts))

    entry.fetch("groups")
  end

  def self.join_texts(texts, prefix_length)
    [texts.first[prefix_length..], *texts.drop(1)].join(" ")
  end

  def self.normalize(external_id, texts)
    groups = plan(external_id, texts)
    return texts unless groups

    offset = 0
    groups.map do |length, prefix_length|
      text = join_texts(texts.slice(offset, length), prefix_length)
      offset += length
      text
    end
  end
end
