require "json"

module Ark::Bedrock
  module TraceParser
    PAGE_NUMBER_KEY = "x-amz-bedrock-kb-document-page-number"

    def self.parse(
      payload : Bytes,
      knowledge_bases : Set(String),
      action_groups : Set(String),
      search_queries : Array(String),
      sources : Array(String),
      seen_sources : Set(String),
    ) : String?
      json = JSON.parse(String.new(payload))
      trace = json["trace"]? || return nil

      extract_preprocessing_rationale(trace) ||
        extract_orchestration(trace, knowledge_bases, action_groups, search_queries, sources, seen_sources)
    end

    private def self.extract_preprocessing_rationale(trace : JSON::Any) : String?
      trace.dig?("preProcessingTrace", "modelInvocationOutput", "parsedResponse", "rationale")
        .try(&.as_s?)
        .try { |value| value.empty? ? nil : value }
    end

    private def self.extract_orchestration(
      trace : JSON::Any,
      knowledge_bases : Set(String),
      action_groups : Set(String),
      search_queries : Array(String),
      sources : Array(String),
      seen_sources : Set(String),
    ) : String?
      orch = trace["orchestrationTrace"]? || return nil

      if kb_id = orch.dig?("invocationInput", "knowledgeBaseLookupInput", "knowledgeBaseId").try(&.as_s?)
        knowledge_bases << kb_id
      end

      if query = orch.dig?("invocationInput", "knowledgeBaseLookupInput", "text").try(&.as_s?)
        search_queries << query unless query.empty?
      end

      if ag_name = orch.dig?("invocationInput", "actionGroupInvocationInput", "actionGroupName").try(&.as_s?)
        action_groups << ag_name
      end

      extract_sources(orch, sources, seen_sources)

      orch.dig?("rationale", "text")
        .try(&.as_s?)
        .try { |value| value.empty? ? nil : value }
    end

    private def self.extract_sources(
      orch : JSON::Any,
      sources : Array(String),
      seen_sources : Set(String),
    ) : Nil
      refs = orch.dig?("observation", "knowledgeBaseLookupOutput", "retrievedReferences").try(&.as_a?) || return

      refs.each do |ref|
        uri = ref.dig?("location", "s3Location", "uri").try(&.as_s?) || next
        name = File.basename(uri).strip
        next if name.empty? || seen_sources.includes?(name)

        if page = ref.dig?("metadata", PAGE_NUMBER_KEY).try(&.as_s?)
          name += ", p. #{page}"
        end

        seen_sources << name
        sources << name
      end
    end
  end
end
