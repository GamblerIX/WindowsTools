import os
import tokenize
import io

def remove_python_comments(source):
    """使用 tokenize 安全地移除 Python 注释，不会破坏字符串中的 # 字符。"""
    try:
        result = []
        g = tokenize.generate_tokens(io.StringIO(source).readline)
        for toktype, tokval, _, _, _ in g:
            if toktype == tokenize.COMMENT:
                continue
            result.append((toktype, tokval))
        return tokenize.untokenize(result)
    except Exception as e:
        print(f"Tokenize failed: {e}, falling back to original.")
        return source

def remove_comments_from_file(filepath):
    ext = os.path.splitext(filepath)[1].lower()
    
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    if ext == '.py':
        # Preserve shebang
        shebang = ""
        if content.startswith('#!'):
            lines = content.splitlines(True)
            shebang = lines[0]
            content = "".join(lines[1:])
        
        new_content = shebang + remove_python_comments(content)
        
    elif ext == '.ps1':
        lines = content.splitlines(True)
        new_lines = []
        metadata_count = 0
        for i, line in enumerate(lines):
            stripped = line.strip()
            # Preserve first 2 lines of metadata
            if metadata_count < 2 and stripped.startswith('#'):
                new_lines.append(line)
                metadata_count += 1
                continue
            
            # Very simple logic for ps1: only remove lines starting with #
            # Avoid inline comment removal to be safe with quoted strings
            if not stripped.startswith('#'):
                new_lines.append(line)
        new_content = "".join(new_lines)
                    
    elif ext in ['.bat', '.cmd']:
        lines = content.splitlines(True)
        new_lines = []
        metadata_count = 0
        for i, line in enumerate(lines):
            stripped = line.strip()
            stripped_upper = stripped.upper()
            is_comment = stripped.startswith('::') or stripped_upper.startswith('REM ')
            
            # Preserve first 2 lines of metadata
            if is_comment and metadata_count < 2:
                new_lines.append(line)
                metadata_count += 1
                continue
            
            if not is_comment:
                new_lines.append(line)
        new_content = "".join(new_lines)
    else:
        return
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)

def process_directory(directory):
    for root, dirs, files in os.walk(directory):
        # Skip hidden dirs like .git or .github
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for file in files:
            if file.endswith(('.py', '.ps1', '.bat', '.cmd')):
                if file == 'remove.py':
                    continue
                filepath = os.path.join(root, file)
                print(f"Processing {filepath}...")
                remove_comments_from_file(filepath)

if __name__ == "__main__":
    base_dir = os.path.dirname(os.path.abspath(__file__))
    process_directory(base_dir)
