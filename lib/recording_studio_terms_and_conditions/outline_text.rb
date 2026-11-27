# frozen_string_literal: true

require "erb"
require "nokogiri"

module RecordingStudioTermsAndConditions
  module Outline # rubocop:disable Metrics/ModuleLength
    SectionDraft = Struct.new(:heading, :clauses, :number)

    class << self # rubocop:disable Metrics/ClassLength
      def assemble(terms_recording)
        sections(terms_recording).flat_map { |section| section_html(section) }.join
      end

      def preview(terms_recording, title: nil)
        {
          title: title.presence || terms_recording.recordable.title.to_s,
          body: assemble(terms_recording)
        }
      end

      def split(body, title:)
        text = body.to_s.strip
        heading = title.to_s.strip.presence || "Terms"
        return [SectionDraft.new(heading, [])] if text.empty?
        return split_html(text, heading) if text.include?("<")

        split_plain(text, heading)
      end

      private

      def section_html(section)
        [heading_html(section), *section.clauses.map { |clause| clause_html(clause) }]
      end

      def heading_html(section)
        %(<h2>#{escape(section.number)}. #{escape(section.heading)}</h2>)
      end

      def clause_html(clause)
        number = escape(clause.number)
        body = clause.body.to_s.strip
        return %(<p>#{number} #{escape(body)}</p>) unless body.include?("<")

        inject_number(body, number)
      end

      def inject_number(body, number)
        updated = body.sub(/\A(\s*<(?:p|li|div|h[1-6])\b[^>]*>)/i, "\\1#{number} ")
        return updated if updated != body

        %(<p>#{number}</p>#{body})
      end

      def escape(value)
        ERB::Util.html_escape(value.to_s)
      end

      def split_html(text, title)
        drafts = html_drafts(Nokogiri::HTML.fragment(text), title)
        return fallback(text, title) if drafts.empty?
        return fallback(text, title) if drafts.one? && drafts.first.clauses.empty?

        drafts
      end

      def html_drafts(fragment, title)
        drafts = []
        current = nil
        each_block(fragment) do |node|
          current = heading_draft(drafts, node, title) if heading_node?(node)
          next if heading_node?(node)

          current = start_draft(drafts, title) if current.nil?
          append_node(current, node)
        end
        drafts
      end

      def heading_draft(drafts, node, title)
        number = next_section_number(drafts)
        draft = SectionDraft.new(strip_heading_number(node.text.strip.presence || title, number: number), [], number)
        drafts << draft
        draft
      end

      def each_block(node, &block)
        node.children.each do |child|
          next if blank_node?(child)
          next each_block(child, &block) if wrapper_node?(child)

          yield child
        end
      end

      def wrapper_node?(node)
        node.element? && !heading_node?(node) && !list_node?(node) && !%w[p li].include?(node.name)
      end

      def split_plain(text, title)
        return split_markdown(text, title) if text.match?(/^\#{1,6}\s+\S/)
        return paragraph_draft(text, title) if text.include?("\n\n")

        fallback(text, title)
      end

      def paragraph_draft(text, title)
        parts = text.split(/\n{2,}/).map(&:strip).reject(&:empty?)
        return fallback(text, title) if parts.size < 2

        [numbered_section(title, parts)]
      end

      def numbered_section(title, parts)
        number = "1"
        clauses = parts.each_with_index.map { |part, index| strip_clause_number(part, number: "1.#{index + 1}") }
        SectionDraft.new(strip_heading_number(title, number: number), clauses, number)
      end

      def split_markdown(text, title) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        drafts = []
        current = nil
        buffer = []
        text.each_line do |line|
          if (match = line.match(/\A\#{1,6}\s+(.+)\s*\z/))
            current = flush_markdown(drafts, current, buffer, title)
            number = next_section_number(drafts)
            current = SectionDraft.new(strip_heading_number(match[1].strip, number: number), [], number)
            drafts << current
          elsif line.strip.empty?
            current = flush_markdown(drafts, current, buffer, title)
          else
            current = start_draft(drafts, title) if current.nil?
            buffer << line.strip
          end
        end
        flush_markdown(drafts, current, buffer, title)
        drafts.empty? ? fallback(text, title) : drafts
      end

      def flush_markdown(drafts, current, buffer, title)
        paragraph = buffer.join("\n").strip
        buffer.clear
        return current if paragraph.empty?

        current = start_draft(drafts, title) if current.nil?
        push_clause(current, paragraph)
        current
      end

      def start_draft(drafts, title)
        number = next_section_number(drafts)
        draft = SectionDraft.new(strip_heading_number(title, number: number), [], number)
        drafts << draft
        draft
      end

      def append_node(section, node)
        if list_node?(node)
          append_list(section, node)
        elsif node.element? && %w[p li].include?(node.name)
          push_clause(section, node.to_html)
        elsif node.text.to_s.strip.present?
          push_clause(section, node.element? ? node.to_html : node.text.strip)
        end
      end

      def append_list(section, node)
        items = node.element_children.select { |child| child.name == "li" }
        if items.any?
          items.each { |item| push_clause(section, item.to_html) }
        else
          push_clause(section, node.to_html)
        end
      end

      def heading_node?(node)
        node.element? && node.name.match?(/\Ah[1-6]\z/)
      end

      def list_node?(node)
        node.element? && %w[ul ol].include?(node.name)
      end

      def blank_node?(node)
        !node.element? && node.text.to_s.strip.empty?
      end

      def fallback(text, title)
        [numbered_section(title, [text])]
      end

      def next_section_number(drafts)
        (drafts.size + 1).to_s
      end

      def push_clause(section, text)
        section.clauses << strip_clause_number(text, number: "#{section.number}.#{section.clauses.size + 1}")
      end

      def strip_heading_number(text, number:)
        prefix = "#{number}. "
        value = text.to_s
        value = value.delete_prefix(prefix) while value.start_with?(prefix)
        value
      end

      def strip_clause_number(text, number:) # rubocop:disable Metrics/MethodLength
        prefix = "#{number} "
        html = text.to_s
        loop do
          stripped = html.sub(/\A(\s*<(?:p|li|div|h[1-6])\b[^>]*>)\s*#{Regexp.escape(prefix)}/i, "\\1")
          if stripped != html
            html = stripped
            next
          end
          break unless html.start_with?(prefix)

          html = html.delete_prefix(prefix)
        end
        html
      end
    end
  end
end
