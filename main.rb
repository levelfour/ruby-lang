#!/usr/bin/env ruby
# coding: utf-8

module TOKEN
	ADD = 1 # 加算
	SUB = 1 # 減算
	MUL = 2 # 乗算
	DIV = 2 # 除算
	MOD = 2 # 剰余
	POW = 3 # 累乗
	IMD = 1000 # 即値
end

module OP
	STR = {
		"+" => TOKEN::ADD,
		"-" => TOKEN::SUB,
		"*" => TOKEN::MUL,
		"/" => TOKEN::DIV,
		"%" => TOKEN::MOD,
		"^" => TOKEN::POW,
	}
	PROC = {
		"+" => Proc.new do |x, y| x + y end,
		"-" => Proc.new do |x, y| x - y end,
		"*" => Proc.new do |x, y| x * y end,
		"/" => Proc.new do |x, y| x / y end,
		"%" => Proc.new do |x, y| x % y end,
		"^" => Proc.new do |x, y| x ** y end,
	}
end

# 式木
class Expr
	def initialize(val = 0)
		@val = val
	end

	def eval
		@val
	end

	def inspect
		"Expr(#{@val})"
	end
end	

# 式木のノード（二項演算子）
class BinOpExpr < Expr
	def initialize(op, left, right)
		@op = op
		@left = left
		@right = right
	end

	def eval
		# 演算子に相当するプロシージャ(OP::PROC[@op])を呼ぶ
		OP::PROC[@op].call(@left.eval, @right.eval)
	end

	def inspect
		"BinOp(#{@op})\nleft=#{@left.inspect}\nright=#{@right.inspect}"
	end
end

# トークナイザ
#   Tokenizer << [token_str, token_type] の形でトークンを追加する
class Tokenizer
	class Token
		attr_reader :s, :type, :priority
		def initialize(s, type)
			@s = s
			@type = type
			case @type
			when :immidiate # 即値
				@priority = TOKEN::IMD
			when :operator # 演算子
				@priority = OP::STR[@s]
			end
		end
	end

	def initialize(tokens = [])
		@tokens = tokens
	end

	def <<(tok)
		@tokens << Token.new(tok[0], tok[1])
	end

	def [](index)
		@tokens[index]
	end

	def length
		@tokens.length
	end

	# トークン配列の中からrootになる要素（優先度min）のインデックスを返す
	# 優先度が同じトークンは後方検索
	def root
		r = @tokens.reverse.each_with_index.min_by { |t,i| t.priority }.last
		@tokens.length - r - 1
	end

	def tokenize
		return _tokenize(self)
	end

	def _tokenize(tokens)
		if tokens.length == 1
			if tokens[0].type == :immidiate
				if /^\d+\.\d+/ =~ tokens[0].s
					return Expr.new(tokens[0].s.to_f)
				elsif /^\d+/ =~ tokens[0].s
					return Expr.new(tokens[0].s.to_i)
				end
			end
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
		if /^\d+\.\d+/ =~ s[i..s.length-1] || /^\d+/ =~ s[i..s.length-1] 
			token << [$&, :immidiate]
		# デリミタ
		elsif /^\s+/ =~ s[i..s.length-1]
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
			
			# それ以外は例外
			if !$&
				raise SyntaxError, "Invalid token in `#{s}`"
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
		token = parse(s)
		tree = token.tokenize
		p tree.eval
		print ">>> "
	end
rescue Interrupt => e
	print "\nbye\n"
rescue SyntaxError => e
	print e, "\n"
end
