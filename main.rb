#!/usr/bin/env ruby
# coding: utf-8

require 'forwardable'

module TOKEN
	SBT = 0 # 代入
	EQL = 0 # 比較
	NEQ = 0 # 比較(NOT EQUAL)
	LES = 0 # <
	LEQ = 0 # <=
	GRT = 0 # >
	GEQ = 0 # >=
	ADD = 1 # 加算
	SUB = 1 # 減算
	MUL = 2 # 乗算
	DIV = 2 # 除算
	MOD = 2 # 剰余
	POW = 3 # 累乗
	IMMEDIATE = 1000 # 即値
	IDENTIFIER = IMMEDIATE.pred # 識別子
	DELIMITER = IMMEDIATE.succ # デリミタ

	# 各トークンの正規表現パターン
	PATTERN_INT			= /^\d+/
	PATTERN_DOUBLE		= /^\d+\.\d+/
	PATTERN_IDENTIFIER	= /^[A-Za-z][A-Za-z0-9]*/
	PATTERN_SPACE		= /^\s+/
end

module OP
	STR = {
		"<-" => TOKEN::SBT,
		"=" => TOKEN::EQL,
		"!=" => TOKEN::NEQ,
		"<=" => TOKEN::LEQ,
		"<" => TOKEN::LES,
		">=" => TOKEN::GEQ,
		">" => TOKEN::GRT,
		"+" => TOKEN::ADD,
		"-" => TOKEN::SUB,
		"*" => TOKEN::MUL,
		"/" => TOKEN::DIV,
		"%" => TOKEN::MOD,
		"^" => TOKEN::POW,
	}
	PROC = {
		"<-" => lambda { |x, y| x.substitute y },
		"=" => lambda { |x, y| x == y },
		"!=" => lambda { |x, y| x != y },
		"<" => lambda { |x, y| x < y },
		"<=" => lambda { |x, y| x <= y },
		">" => lambda { |x, y| x > y },
		">=" => lambda { |x, y| x >= y },
		"+" => lambda { |x, y| x + y },
		"-" => lambda { |x, y| x - y },
		"*" => lambda { |x, y| x * y },
		"/" => lambda { |x, y| x / y },
		"%" => lambda { |x, y| x % y },
		"^" => lambda { |x, y| x ** y },
	}
end

DELIMITER = {
	:paren => ["(", ")"],
}

# 式木
class Expr
	def initialize(val = 0)
		@val = val
	end

	def evaluate
		@val
	end

	def inspect
		"Expr(#{@val})"
	end
end	

# 式木のノード（変数）
class VarExpr < Expr
	def initialize(s, val)
		@s = s
		@val = val
	end

	def substitute(val)
		@val = val
	end

	def inspect
		"VarExpr(#{@s} = #{@val})"
	end
end


# 式木のノード（二項演算子）
class BinOpExpr < Expr
	def initialize(op, left, right)
		@op = op
		@left = left
		@right = right
	end

	def evaluate
		# 演算子に相当するプロシージャ(OP::PROC[@op])を呼ぶ
		if @op == "<-"
			# 代入式は左辺値が変数であることを確認
			if @left.kind_of?(VarExpr)
				OP::PROC[@op].call(@left, @right.evaluate)
			else 
				raise SyntaxError, "#{__method__}: lvalue must be variable"
			end
		else
			OP::PROC[@op].call(@left.evaluate, @right.evaluate)
		end
	end

	def inspect
		"BinOp(#{@op})\nleft=#{@left.inspect}\nright=#{@right.inspect}"
	end
end

# トークナイザ
#   Tokenizer << [token_str, token_type] の形でトークンを追加する
class Tokenizer
	extend Forwardable

	class Token
		attr_reader :s, :type, :priority
		def initialize(s, type)
			@s = s
			@type = type
			case @type
			when :immidiate # 即値
				@priority = TOKEN::IMMEDIATE
			when :operator # 演算子
				@priority = OP::STR[@s]
			when :identifier # 識別子
				@priority = TOKEN::IDENTIFIER
			when :delimiter # デリミタ
				@priority = TOKEN::DELIMITER
			end
		end
	end

	def initialize(tokens = [])
		@tokens = tokens
	end

	def <<(tok)
		@tokens << Token.new(tok[0], tok[1])
	end

	# delegate
	def_delegators :@tokens, :[], :length, :first, :last

	# トークン配列の中からrootになる要素（優先度min）のインデックスを返す
	# 優先度が同じトークンは後方検索
	def root
		lpi = @tokens.index {|t| t.s == DELIMITER[:paren][0] }
		rpi = @tokens.rindex {|t| t.s == DELIMITER[:paren][1] }
		if !lpi.nil? && !rpi.nil? && lpi < rpi
			lpi = @tokens.length - lpi - 1
			rpi = @tokens.length - rpi - 1
			r = @tokens.reverse.each_with_index.min_by { |t,i|
				t.priority + ((rpi <= i && i <= lpi) ? TOKEN::DELIMITER : 0)
			}.last
			@tokens.length - r - 1
		elsif lpi.nil? && rpi.nil?
			r = @tokens.reverse.each_with_index.min_by { |t,i|
				t.priority
			}.last
			@tokens.length - r - 1
		else
			raise SyntaxError, "#{__method__}: Invalid parenthesis"
		end
	end

	def tokenize
		return _tokenize(self)
	end

	def _tokenize(tokens)
		if tokens.length == 1
			# ASTの終端ノードが即値だった場合
			if tokens[0].type == :immidiate
				# 実数
				if TOKEN::PATTERN_DOUBLE  =~ tokens[0].s
					return Expr.new(tokens[0].s.to_f)
				# 整数
				elsif TOKEN::PATTERN_INT =~ tokens[0].s
					return Expr.new(tokens[0].s.to_i)
				end
			# ASTの終端ノードが識別子だった場合
			elsif tokens[0].type == :identifier && TOKEN::PATTERN_IDENTIFIER =~ tokens[0].s
				return VarExpr.new($&, 0)
			else
				raise SyntaxError, "#{__method__}: Invalid syntax `#{tokens[0].s}`"
			end
		elsif tokens.first.s == DELIMITER[:paren][0] && tokens.last.s == DELIMITER[:paren][1]
			tokens = Tokenizer.new(tokens[1..tokens.length-2])
		end
		# トークン配列の中からrootになる要素（優先度min）を探す
		# rはその要素の@tokensにおけるindex
		r = tokens.root
		left = _tokenize(Tokenizer.new(tokens[0..r-1]))
		right = _tokenize(Tokenizer.new(tokens[r+1..tokens.length-1]))
		expr = BinOpExpr.new(tokens[r].s, left, right)
	end

	# pメソッドで出力するときに整形する
	def inspect
		str = ""
		@tokens.each { |tok|
			str += "\"#{tok.s}\"\t=> #{tok.type}\t(priority: #{tok.priority})\n"
		}
		str
	end
end

# 文字列sをパースする
def parse(s)
	i = 0
	token = Tokenizer.new
	while i < s.length do
		# 実数値または整数値
		if TOKEN::PATTERN_DOUBLE =~ s[i..s.length-1] || TOKEN::PATTERN_INT =~ s[i..s.length-1] 
			token << [$&, :immidiate]
		# 識別子
		elsif TOKEN::PATTERN_IDENTIFIER =~ s[i..s.length-1]
			token << [$&, :identifier]
		# 空白
		elsif TOKEN::PATTERN_SPACE =~ s[i..s.length-1]
			# do nothing
		else
			# 演算子
			OP::STR.each do |x|
				re = /^#{Regexp.escape("#{x[0]}")}/
				if re =~ s[i..s.length-1] 
					token << [$&, :operator]
					break
				end
			end

			# デリミタ
			if !$&
				DELIMITER.each do |k,v|
					re1 = /^#{Regexp.escape(v[0])}/
					re2 = /^#{Regexp.escape(v[1])}/
					if re1 =~ s[i..s.length-1] || re2 =~ s[i..s.length-1]
						token << [$&, :delimiter]
						break
					end
				end
			end
			
			# それ以外は例外
			if !$&
				raise SyntaxError, "#{__method__}: Invalid token in `#{s}`"
			end
		end
		i += $&.length
	end
	return token
end

# main-loop
begin
	print ">>> "
	while s = gets.chomp! do
		if s.empty?
			print ">>> "
			next
		end
		token = parse(s)				# 字句解析
		tree = token.tokenize			# 構文解析
		print "=> #{tree.evaluate}\n"	# 式木の評価
		print ">>> "
	end
rescue Interrupt => e
	print "\nbye\n"
rescue SyntaxError => e
	print e, "\n"
end
