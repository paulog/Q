require 'qlang/api'

require 'qlang/parser/base'
require 'qlang/parser/matrix_parser'
require 'qlang/parser/vector_parser'
require 'qlang/parser/list_parser'
require 'qlang/parser/func_parser'
require 'qlang/parser/integral_parser'
require 'qlang/parser/limit_parser'
require 'qlang/parser/sigma_parser'

require 'qlang/parser/formula_parser'

module Qlang
  module Parser
    include Lexer::Tokens
    SYM = '\w+'
    ONEHASH = "#{ANYSP}#{SYM}#{CLN}#{ANYSP}#{VARNUM}#{ANYSP}" # sdf: 234
    def execute(lexed)
      time = Time.now
      until lexed.token_str =~ /\A:(NLIN|R)\d+\z/
        fail "I'm so sorry, something wrong. Please feel free to report this." if Time.now > time + 10

        case lexed.token_str
        when /:(vector)(\d+)/, /:(matrix)(\d+)/, /:(tmatrix)(\d+)/, /:(integral)(\d+)/, /:(def_func)(\d+)/, /:(differential)(\d+)/, /:(limit)(\d+)/, /:(sigma)(\d+)/
          token_els = lexed.get_els($2)

          parsed = case $1
          when 'vector'
            VectorParser.execute(token_els)
          when 'matrix'
            MatrixParser.execute(token_els)
          when 'tmatrix'
            MatrixParser.execute(token_els, trans: true)
          when 'limit'
            LimitParser.execute(token_els)
          when 'integral'
            IntegralParser.execute(token_els)
          when 'def_func'
            FuncParser.execute(token_els)
          when 'sigma'
            SigmaParser.execute(token_els)
          when 'differential'
            del_var, formula = token_els
            "d/d#{del_var}(#{FormulaParser.execute(formula)})"
          end
          lexed.parsed!(parsed, $2)

        when /:LPRN(\d+):CONT(\d+):RPRN(\d+)/
          tokens_range = $1.to_i..$3.to_i
          token_val =

          lexed.parsed!(
            lexed.get_value($2).parentheses,
            tokens_range
          )

        when /:LBRCS(\d+):CONT(\d+):RBRCS(\d+)/
          tokens_range = $1.to_i..$3.to_i
          token_val = lexed.get_value($2)

          cont = case token_val
            when /#{ONEHASH}(#{CMA}#{ONEHASH})*/
              ListParser.execute(token_val)
            else
              token_val
            end

          lexed.parsed!(cont, tokens_range)

        when /:FUNCCN(\d+)/
          token_val = lexed.get_value($1)
          lexed.parsed!(token_val.parentheses, $1)

        when /:CONT(\d+)/
          lexed.parsed!(lexed.get_value($1), $1)
        end
        lexed.squash!(($1.to_i)..($1.to_i+1)) if lexed.token_str =~ /:(?:CONT|R)(\d+):(?:CONT|R)(\d+)/
      end

      LangEqualizer.execute(
        lexed.values.join
      )
    end
    module_function :execute

    # FIXIT
    class LangEqualizer
      def self.execute(str)
        case $meta_info.lang
        when :ruby
          str.gsub(/\^/, '**')
        else
          str
        end
      end
    end

  end
end
