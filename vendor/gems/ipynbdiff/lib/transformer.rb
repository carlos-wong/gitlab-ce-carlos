# frozen_string_literal: true

module IpynbDiff
  require 'oj'

  class InvalidNotebookError < StandardError
  end

  # Returns a markdown version of the Jupyter Notebook
  class Transformer
    require 'json'
    require 'yaml'
    require 'output_transformer'
    require 'symbolized_markdown_helper'
    require 'symbol_map'
    require 'transformed_notebook'
    include SymbolizedMarkdownHelper

    @include_frontmatter = true

    def initialize(include_frontmatter: true, hide_images: false)
      @include_frontmatter = include_frontmatter
      @hide_images = hide_images
      @out_transformer = OutputTransformer.new(hide_images)
    end

    def validate_notebook(notebook)
      notebook_json = Oj::Parser.usual.parse(notebook)

      return notebook_json if notebook_json.key?('cells')

      raise InvalidNotebookError
    rescue EncodingError, Oj::ParseError, JSON::ParserError
      raise InvalidNotebookError
    end

    def transform(notebook)
      return TransformedNotebook.new unless notebook

      notebook_json = validate_notebook(notebook)
      transformed = transform_document(notebook_json)
      symbol_map = SymbolMap.parse(notebook)

      TransformedNotebook.new(transformed, symbol_map)
    end

    def transform_document(notebook)
      symbol = JsonSymbol.new('.cells')

      transformed_blocks = notebook['cells'].map.with_index do |cell, idx|
        decorate_cell(transform_cell(cell, notebook, symbol / idx), cell, symbol / idx)
      end

      transformed_blocks.prepend(transform_metadata(notebook)) if @include_frontmatter
      transformed_blocks.flatten
    end

    def decorate_cell(rows, cell, symbol)
      tags = cell['metadata']&.fetch('tags', [])
      type = cell['cell_type'] || 'raw'

      [
        _(symbol, %(%% Cell type:#{type} id:#{cell['id']} tags:#{tags&.join(',')})),
        _,
        rows,
        _
      ]
    end

    def transform_cell(cell, notebook, symbol)
      cell['cell_type'] == 'code' ? transform_code_cell(cell, notebook, symbol) : transform_text_cell(cell, symbol)
    end

    def transform_code_cell(cell, notebook, symbol)
      [
        _(symbol / 'source', %(``` #{notebook.dig('metadata', 'kernelspec', 'language') || ''})),
        symbolize_array(symbol / 'source', cell['source'], &:rstrip),
        _(nil, '```'),
        transform_outputs(cell['outputs'], symbol)
      ]
    end

    def transform_outputs(outputs, symbol)
      transformed = outputs.map
                           .with_index { |output, i| @out_transformer.transform(output, symbol / ['outputs', i]) }
                           .compact
                           .map { |el| [_, el] }

      [
        transformed.empty? ? [] : [_, _(symbol / 'outputs', '%% Output')],
        transformed
      ]
    end

    def transform_text_cell(cell, symbol)
      symbolize_array(symbol / 'source', cell['source'], &:rstrip)
    end

    def transform_metadata(notebook_json)
      as_yaml = {
        'jupyter' => {
          'kernelspec' => notebook_json['metadata']['kernelspec'],
          'language_info' => notebook_json['metadata']['language_info'],
          'nbformat' => notebook_json['nbformat'],
          'nbformat_minor' => notebook_json['nbformat_minor']
        }
      }.to_yaml

      as_yaml.split("\n").map { |l| _(nil, l) }.append(_(nil, '---'), _)
    end
  end
end
