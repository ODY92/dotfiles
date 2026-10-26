import ast
import math
import operator
import os
from pathlib import Path

OPERATORS = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv, ast.Mod: operator.mod, ast.Pow: operator.pow}

def calculate(text):
    if len(text) > 120 or not any(character.isdigit() for character in text):
        return None
    try:
        tree = ast.parse(text, mode='eval')
        if sum(1 for _ in ast.walk(tree)) > 40:
            return None
        def visit(node):
            if isinstance(node, ast.Constant) and type(node.value) in (int, float):
                value = node.value
            elif isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub)):
                value = visit(node.operand) * (-1 if isinstance(node.op, ast.USub) else 1)
            elif isinstance(node, ast.BinOp) and type(node.op) in OPERATORS:
                left, right = visit(node.left), visit(node.right)
                if isinstance(node.op, ast.Pow) and abs(right) > 12:
                    raise ValueError()
                value = OPERATORS[type(node.op)](left, right)
            else:
                raise ValueError()
            if not math.isfinite(value) or abs(value) > 1e18:
                raise ValueError()
            return value
        return f'{visit(tree.body):.12g}'
    except (SyntaxError, ValueError, TypeError, ZeroDivisionError, OverflowError):
        return None

def rank(query, title, detail=''):
    query, title, detail = query.casefold().strip(), title.casefold(), detail.casefold()
    if not query:
        return 1
    if query == title:
        return 100
    if title.startswith(query):
        return 80
    if query in title:
        return 60
    if all(word in f'{title} {detail}' for word in query.split()):
        return 30
    return 0

def index_files(home=None, limit=20000):
    home = Path(home or Path.home())
    result = []
    roots = [home / name for name in ('Documents', 'Downloads', 'Téléchargements', 'Desktop', 'Bureau')]
    skipped = {'node_modules', 'target', 'venv', '__pycache__', 'work', 'runtime'}
    for root in roots:
        if not root.is_dir() or root.is_symlink():
            continue
        for current, directories, files in os.walk(root, followlinks=False):
            relative = Path(current).relative_to(root)
            directories[:] = [name for name in directories if not name.startswith('.') and name not in skipped and not (Path(current) / name).is_symlink() and len(relative.parts) < 3]
            for name in files:
                if name.startswith('.'):
                    continue
                path = Path(current) / name
                if path.is_symlink():
                    continue
                result.append({'title': name, 'detail': str(path.parent.relative_to(home)), 'path': str(path)})
                if len(result) >= limit:
                    return result
    return result
