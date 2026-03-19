require "json"

module Ark::Bedrock
  module TraceParser
    def self.parse(
      payload : Bytes,
      knowledge_bases : Set(String),
      action_groups : Set(String),
      search_queries : Array(String),
    ) : String?
      json = JSON.parse(String.new(payload))
      trace = json["trace"]? || return nil

      rationale = extract_rationale(trace)
      extract_orchestration(trace, knowledge_bases, action_groups, search_queries)
      rationale
    end

    private def self.extract_rationale(trace : JSON::Any) : String?
      trace.dig?("preProcessingTrace", "modelInvocationOutput", "parsedResponse", "rationale")
        .try(&.as_s?)
        .try { |value| value.empty? ? nil : value }
    end

    private def self.extract_orchestration(
      trace : JSON::Any,
      knowledge_bases : Set(String),
      action_groups : Set(String),
      search_queries : Array(String),
    ) : Nil
      orch = trace["orchestrationTrace"]? || return

      if kb_id = orch.dig?("invocationInput", "knowledgeBaseLookupInput", "knowledgeBaseId").try(&.as_s?)
        knowledge_bases << kb_id
      end

      if query = orch.dig?("invocationInput", "knowledgeBaseLookupInput", "text").try(&.as_s?)
        search_queries << query unless query.empty?
      end

      if ag_name = orch.dig?("invocationInput", "actionGroupInvocationInput", "actionGroupName").try(&.as_s?)
        action_groups << ag_name
      end
    end
  end
end
