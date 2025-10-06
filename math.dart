import 'dart:math';
import 'dart:collection';

int evaluator(String s, Map<String, double> values) {
  if (s.isEmpty) throw ArgumentError('Empty expression');

  final intValues = <String, int>{};
  for (final entry in values.entries) {
    final v = entry.value;
    if (v != v.roundToDouble()) {
      throw ArgumentError('Variable ${entry.key} must be an integer, got $v');
    }
    // Приводим ключ к верхнему регистру для единообразия
    intValues[entry.key.toUpperCase()] = v.toInt();
  }

  s = s.replaceAll(' ', '');
  final tokens = _tokenize(s);
  _validateTokens(tokens, intValues);
  final rpn = _toRPN(tokens, intValues);
  return _evaluateRPN(rpn);
}

sealed class Token {}
class NumberToken extends Token {
  final int value;
  NumberToken(this.value);
}
class VariableToken extends Token {
  final String name;
  VariableToken(this.name);
}
class OperatorToken extends Token {
  final String op;
  OperatorToken(this.op);
}
class ParenToken extends Token {
  final String symbol;
  ParenToken(this.symbol);
}

List<Token> _tokenize(String s) {
  final tokens = <Token>[];
  int i = 0;

  bool isUnaryMinus() {
    if (tokens.isEmpty) return true;
    final last = tokens.last;
    return last is ParenToken && last.symbol == '(' || last is OperatorToken;
  }

  while (i < s.length) {
    final c = s[i];

    if (c == '+' || c == '*' || c == '/' || c == '^') {
      tokens.add(OperatorToken(c));
      i++;
    } else if (c == '-') {
      if (isUnaryMinus()) {
        int start = i;
        i++;
        while (i < s.length && s[i].compareTo('0') >= 0 && s[i].compareTo('9') <= 0) {
          i++;
        }
        if (i == start + 1 && i < s.length && s[i] == '(') {
          tokens.add(NumberToken(0));
          tokens.add(OperatorToken('-'));
          tokens.add(ParenToken('('));
          i++;
        } else {
          final numStr = s.substring(start, i);
          tokens.add(NumberToken(int.parse(numStr)));
        }
      } else {
        tokens.add(OperatorToken('-'));
        i++;
      }
    } else if (c.compareTo('0') >= 0 && c.compareTo('9') <= 0) {
      int start = i;
      while (i < s.length && s[i].compareTo('0') >= 0 && s[i].compareTo('9') <= 0) {
        i++;
      }
      tokens.add(NumberToken(int.parse(s.substring(start, i))));
    } else if ((c.compareTo('a') >= 0 && c.compareTo('z') <= 0) ||
        (c.compareTo('A') >= 0 && c.compareTo('Z') <= 0)) {
      // Разрешаем ЛЮБУЮ латинскую букву (строчную или заглавную)
      tokens.add(VariableToken(c.toUpperCase())); // нормализуем к верхнему регистру
      i++;
    } else if (c == '(') {
      tokens.add(ParenToken('('));
      i++;
    } else if (c == ')') {
      tokens.add(ParenToken(')'));
      i++;
    } else {
      throw ArgumentError('Invalid character: $c');
    }
  }
  return tokens;
}

void _validateTokens(List<Token> tokens, Map<String, int> values) {
  for (final t in tokens) {
    if (t is VariableToken) {
      if (!values.containsKey(t.name)) {
        throw ArgumentError('Undefined variable: ${t.name}');
      }
    }
  }
}

// приоритет
int _precedence(String op) {
  switch (op) {
    case '^': return 3;
    case '*': return 2;
    case '/': return 2;
    case '+': return 1;
    case '-': return 1;
    default: return 0;
  }
}

bool _isRightAssociative(String op) => op == '^';

List<Token> _toRPN(List<Token> tokens, Map<String, int> values) {
  final output = <Token>[];
  final ops = Queue<Token>();

  for (final token in tokens) {
    if (token is NumberToken) {
      output.add(token);
    } else if (token is VariableToken) {
      output.add(NumberToken(values[token.name]!));
    } else if (token is OperatorToken) {
      final op = token.op;
      while (ops.isNotEmpty) {
        final top = ops.last;
        if (top is! OperatorToken) break;
        if (!_isRightAssociative(op) && _precedence(op) <= _precedence(top.op) ||
            _isRightAssociative(op) && _precedence(op) < _precedence(top.op)) {
          output.add(ops.removeLast());
        } else {
          break;
        }
      }
      ops.add(token);
    } else if (token is ParenToken) {
      if (token.symbol == '(') {
        ops.add(token);
      } else {
        bool found = false;
        while (ops.isNotEmpty) {
          final t = ops.removeLast();
          if (t is ParenToken && t.symbol == '(') {
            found = true;
            break;
          }
          output.add(t);
        }
        if (!found) throw ArgumentError('Mismatched parentheses');
      }
    }
  }

  while (ops.isNotEmpty) {
    final t = ops.removeLast();
    if (t is ParenToken) throw ArgumentError('Mismatched parentheses');
    output.add(t);
  }

  return output;
}

int _evaluateRPN(List<Token> rpn) {
  final stack = <int>[];
  for (final token in rpn) {
    if (token is NumberToken) {
      stack.add(token.value);
    } else if (token is OperatorToken) {
      if (stack.length < 2) throw ArgumentError('Invalid expression');
      final b = stack.removeLast();
      final a = stack.removeLast();
      int res;
      switch (token.op) {
        case '+': res = a + b; break;
        case '-': res = a - b; break;
        case '*': res = a * b; break;
        case '/':
          if (b == 0) throw ArgumentError('Division by zero');
          res = a ~/ b;
          break;
        case '^':
          if (b < 0) throw ArgumentError('Negative exponent not allowed');
          res = pow(a, b).toInt();
          break;
        default:
          throw ArgumentError('Unknown operator: ${token.op}');
      }
      stack.add(res);
    } else {
      throw ArgumentError('Unexpected token');
    }
  }
  if (stack.length != 1) throw ArgumentError('Invalid expression');
  return stack[0];
}


// ====== Тесты ======

void main() {
  testEvaluator('-1+10-3*2', {}, 3);
  testEvaluator('10+20*30+2^3+26-2+4', {}, 646);
  testEvaluator('10+20*30+2^3+(2*3+5*(6-2))', {}, 644);
  testEvaluator('-5+10*x-2*x+6', {'x': 10.0}, 81);
  testEvaluator('-2*x+5*y+100', {'x': 2.0, 'y': -5.0}, 71);
  testEvaluator('5/2', {}, 2);
  testException('(10+5', {});
  testException('', {});
  testException('y+10', {});
  testException('2*x+sin(x)', {});
  testException('12/0', {});
}

void testEvaluator(String expr, Map values, num expected) {
  try {
    num result = evaluator(expr, values);

    // Красивый вывод expected
    String expectedStr =
    expected is int ? expected.toString() : expected.toStringAsFixed(1);

    print(
      'Expression: "$expr" -> Result: $result (Expected: $expectedStr) '
          '${result == expected ? '✅' : '❌'}',
    );
  } catch (e) {
    print('Expression: "$expr" -> Exception thrown: $e ❌');
  }
}

void testException(String expr, Map values) {
  try {
    evaluator(expr, values);
    print('Expression: "$expr" -> No exception ❌');
  } catch (e) {
    print('Expression: "$expr" -> Exception caught as expected ✅');
  }
}


