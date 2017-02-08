# coding: utf-8
require 'strscan'

module Mlua

  class CompileError < Exception
    attr_accessor :filename, :line_no
  end

  ######################################################################
  # パーサー
  ######################################################################
  class Parser

    def initialize( src, filename='(unknown)' )
      @filename = filename
      @scanner = StringScanner.new(src)
      @line_no = 1
      @pos_info = Hash.new
      @bof = true
    end

    def next_token
      # コメントと空白を飛ばす
      if @bof
        if @scanner.scan(/#.*\n/)
          # DO NOTHING
        elsif @scanner.scan(/\$debug/)
          # DO NOTHING
        end
        @bof = false
      end

      while true
        if @scanner.scan(/--\[(=*)\[/)
        level = @scanner[1]
          if @scanner.scan_until(/\]#{level}\]/m)
            @scanner.pre_match.gsub(/\n/){ @line_no += 1 }
          else
            raise "unclosed '--[[' comment"
          end
        elsif @scanner.scan(/ \s+ | --.*?\n /mx)
          has_newline = false
          @scanner[0].gsub(/\n/){ has_newline = true; @line_no += 1 }
          if @need_semi and has_newline
            return [';', ';']
          end
        else
          break
        end
      end
      
      if @scanner.eos?
        r = nil
      elsif @scanner.scan(/\[(=*)\[/)
        level = @scanner[1]
        # '[['で始まる文字列
        if str = @scanner.scan_until(/\]#{level}\]/m)
          r = [:STRING, str[0..-3]]
        else
          raise "unclosed '[[' string"
        end
      elsif @scanner.scan(/\+|-|\*|\/|%|\^|\#|==|~=|<=|>=|<|>|=|\(|\)|\{|\}|\[|\]|;|:|,|\.\.\.|\.\.|\./)
        # 記号
        r = [@scanner[0], @scanner[0]]
      elsif @scanner.scan(/-?0[xX]([\d\w]+)/)
        # 16進数
        r = [:NUMBER, @scanner[1].to_i(16)]
      elsif @scanner.scan(/-?0[bB](\d+)/)
        # 2進数
        r = [:NUMBER, @scanner[1].to_i(2)]
      elsif @scanner.scan(/-?\d+(\.\d+)([eE][+-]\d+)/)
        # 10進数
        # TODO: e表記対応
        r = [:NUMBER, @scanner[0].to_i]
      elsif @scanner.scan(/\w+/)
        # 識別子/キーワード
        if /^(and|break|do|else|elseif|end|false|for|function|if|in|local|nil|not|or|repeat|return|then|true|until|while)$/ === @scanner[0]
          r = [@scanner[0], @scanner[0]]
        else
          r = [:NAME, @scanner[0].to_sym ]
        end
      elsif @scanner.scan(/"([^\\"]|\\.)*"/)
        # ""文字列
        str = @scanner[0][1..-2]
        str = str.gsub(/\\n|\\x../) do |s|
          case s
          when '\n'
            "\n"
          when /\\x/
            s[2..-1].to_i(16).chr
          end
        end
        r = [:STRING, str]
      elsif @scanner.scan(/'([^\\']|\\.)*'/)
        # ''文字列
        r = [:STRING, @scanner[0][1..-2]]
      else
        # :nocov:
        raise "invalid token at #{@line_no}"
        # :nocov:
      end
      # p r
      r
    end

    def info( ast )
      @pos_info[ast] = [@filename,@line_no]
    end

    def parse
      ast = do_parse
      [ast, @pos_info]
    rescue Racc::ParseError
      err = CompileError.new( "#{$!.to_s.strip}" )
      err.filename = @filename
      err.line_no = @line_no
      raise err
    end

    def on_error( token_id, err_val, stack )
      # puts "#{@filename}:#{@line_no}: error with #{token_to_str(token_id)}:#{err_val}"
      # p token_id, err_val, stack
      super
    end


    def local_var(namelist, num)
      # p [:local_var, namelist, num]
      namelist.each do |name|
        emit(:OPMOVE, name)
      end
    end

    def emit(op, *args)
      puts [op, *args].join(', ')
    end

  end

end
