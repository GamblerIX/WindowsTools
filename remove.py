import os

def remove_comments_from_file(filepath):
    ext = os.path.splitext(filepath)[1].lower()
    
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    
    new_lines = []
    
    if ext == '.py':
        for line in lines:
            stripped = line.strip()
            # Preserve shebang and special comments
            if stripped.startswith('#!') or stripped.startswith('# -*-'):
                new_lines.append(line)
                continue
            # Remove full line comments, but preserve indentation for code
            if stripped.startswith('#'):
                continue
            # Keep the line as is (preserve inline comments to be safe)
            new_lines.append(line)
            
    elif ext == '.ps1':
        metadata_preserved = 0
        for line in lines:
            stripped = line.strip()
            # Preserve first 2 comments for metadata
            if metadata_preserved < 2 and stripped.startswith('#'):
                new_lines.append(line)
                metadata_preserved += 1
                continue
            if stripped.startswith('#'):
                continue
            new_lines.append(line)
                    
    elif ext in ['.bat', '.cmd']:
        metadata_preserved = 0
        for line in lines:
            stripped = line.strip()
            stripped_upper = stripped.upper()
            is_comm = stripped.startswith('::') or stripped_upper.startswith('REM ')
            
            if metadata_preserved < 2 and is_comm:
                new_lines.append(line)
                metadata_preserved += 1
                continue
            if is_comm:
                continue
            new_lines.append(line)
    else:
        return
        
    # Remove excessive blank lines
    final_lines = []
    prev_blank = False
    for line in new_lines:
        if not line.strip():
            if not prev_blank:
                final_lines.append(line)
                prev_blank = True
        else:
            final_lines.append(line)
            prev_blank = False
            
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(final_lines)

def process_directory(directory):
    for root, dirs, files in os.walk(directory):
        # Skip hidden dirs
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
