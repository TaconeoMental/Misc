class String
  def is_number?
    true if Float(self) rescue false
  end
end

module TokenType
  VAL_NUM = 0x0

  # Operadores
  OP_ADD = 0x1
  OP_SUB = 0x2
  OP_MUL = 0x3
  OP_DIV = 0x4
  OP_MOD = 0x5

  # Puntuación
  PUNC_LPAR = 0x6
  PUNC_RPAR = 0x7

  UNKNOWN = 0x8
  EOF = 0x9
end

Token = Struct.new(:type, :value) do
  def to_str
    "Token(#{:type}, #{:value}"
  end
end

class Tokenizer
  def initialize(exp)
    @expression = exp
    @tokens = Array.new
  end

  def tokenize
    i = 0
    while i < @expression.length 
      char = @expression[i]
      if char.strip.empty?
        i += 1
        next
      end
      val = String.new
      tok = case char
          when "+"
            TokenType::OP_ADD
          when "-"
            TokenType::OP_SUB
          when "*"
            TokenType::OP_MUL
          when "/"
            TokenType::OP_DIV
          when "%"
            TokenType::OP_MOD
          when "("
            TokenType::PUNC_LPAR
          when ")"
            TokenType::PUNC_RPAR
          else
            val = String.new
            if char.is_number?
              while char && char.is_number?
                val << char
                i += 1
                char = @expression[i]
              end
              i-= 1 # Ordenar código para no tener que hacer esto
              val = val.to_i
              tok = TokenType::VAL_NUM
            else
              tok = TokenType::UNKNOWN
            end
      end
      @tokens.append(Token.new(tok, val))
      i += 1
    end
    @tokens.append(Token.new(TokenType::EOF, nil))
  end
end

module Ast
  # Quiero hacer una clase abstracta, pero no sé si valga la pena en ruby
  class Expression
    def initialize(expr)
      @expr = expr
    end

    def eval
      @expr.eval
    end
  end

  class Num
    def initialize(num)
      @value = num
    end
    
    def eval
      @value
    end
  end

  class BinOp
    def initialize(left, right, op)
      @left = left
      @right = right
      @op = op
      @funcs = {
        TokenType::OP_ADD => ->(x, y) {x + y},
        TokenType::OP_SUB => ->(x, y) {x - y},
        TokenType::OP_MUL => ->(x, y) {x * y},
        TokenType::OP_DIV => ->(x, y) {x / y},
        TokenType::OP_MOD => ->(x, y) {x % y}
      }
    end

    def eval
      @funcs[@op].(@left.eval, @right.eval)
    end
  end

  class UnOp
    def initialize(expr)
      @expr = expr
    end

    def eval
      -@expr.eval
    end
  end
end


class Parser
  # Parser recursivo descendiente. Este es su CFG:
  # exp_prim := suma
  # suma     := mult [(+ | -)  mult]
  # mult     := neg [(% | / | *) neg]
  # neg      := - neg
  #           | expr_sec
  # expr_sec := "(" exp_prim  ")"
  #           | num

  def initialize(tokenizer)
    @tokens = tokenizer.each
    @current_tok = @tokens.next
  end

  def consume(type)
    if type ==  @current_tok.type
        @current_tok = @tokens.next
    else
      puts "Error: Expected '#{type}', but got '#{@current_tok.type}'"
    end
  end

  def expr_primaria
    suma
  end
  
  def suma
    bin_expr(TokenType::OP_ADD, :mul)
  end

  def mul
    bin_expr(TokenType::OP_MUL, :div)
  end
  
  def div
    bin_expr(TokenType::OP_DIV, :mod)
  end
  
  def mod
    bin_expr(TokenType::OP_MOD, :neg)
  end

  def neg
    node = nil
    if @current_tok.type == TokenType::OP_SUB
      consume(TokenType::OP_SUB)
      return Ast::UnOp.new(neg)
    else
      return exp_sec
    end
  end

  def exp_sec
    tok = @current_tok
    tok_type = tok.type
    case tok_type
    when TokenType::VAL_NUM
      consume(tok_type)
      node = Ast::Num.new(tok.value)
    when TokenType::PUNC_LPAR
      consume(tok_type)
      node = expr_primaria
      consume(TokenType::PUNC_RPAR)
    else
      puts "Error: #{tok}. Unexpected end of expression"
      fail
    end
    node
  end

  def parse
    expr_primaria
  end

  private
  def bin_expr(tt, met)
    node = method(met).call
    while tt == @current_tok.type
      consume(tt)
      node = Ast::BinOp.new(node, method(met).call, tt)
    end
    node
  end
end

def main
  return if ARGV.length < 1
  expression = ARGV.[](0)
  tokenizer = Tokenizer.new(expression).tokenize
  parser = Parser.new(tokenizer).parse
  puts parser.eval
end

main


