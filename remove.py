import os
import re

def remove_comments_from_file(filepath):
    ext = os.path.splitext(filepath)[1].lower()
    
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    
    new_lines = []
    
    if ext == '.py':
        for line in lines:
            stripped = line.strip()
            # Preserve shebang or encoding
            if stripped.startswith('#!') or stripped.startswith('# -*-'):
                new_lines.append(line)
            # Remove full line comments
            elif stripped.startswith('#'):
                continue
            else:
                # Remove inline comments (simple version)
                # This could be improved for strings, but for this project's scripts it should be fine
                if '#' in line:
                    parts = line.split('#', 1)
                    # Check if # is inside quotes (very basic check)
                    if not ('"' in parts[0] or "'" in parts[0]):
                        new_lines.append(parts[0].rstrip() + '\n')
                    else:
                        new_lines.append(line)
                else:
                    new_lines.append(line)
                    
    elif ext == '.ps1':
        for i, line in enumerate(lines):
            # Preserve first 2 lines if they are comments (metadata)
            if i < 2 and line.strip().startswith('#'):
                new_lines.append(line)
                continue
            
            stripped = line.strip()
            if stripped.startswith('#'):
                continue
            else:
                # Inline comments removal
                if '#' in line:
                    parts = line.split('#', 1)
                    if not ('"' in parts[0] or "'" in parts[0]):
                        new_lines.append(parts[0].rstrip() + '\n')
                    else:
                        new_lines.append(line)
                else:
                    new_lines.append(line)
                    
    elif ext in ['.bat', '.cmd']:
        for i, line in enumerate(lines):
            # Preserve first 2 lines if they are comments (metadata for UI)
            stripped_upper = line.strip().upper()
            if i < 2 and (line.strip().startswith('::') or stripped_upper.startswith('REM ')):
                new_lines.append(line)
                continue
            
            if line.strip().startswith('::') or stripped_upper.startswith('REM '):
                continue
            else:
                new_lines.append(line)
    else:
        return # Skip other files
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

def process_directory(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(('.py', '.ps1', '.bat', '.cmd')):
                # Don't process this script itself
                if file == 'remove.py':
                    continue
                filepath = os.path.join(root, file)
                print(f"Processing {filepath}...")
                remove_comments_from_file(filepath)

if __name__ == "__main__":
    # Process current directory and scripts
    base_dir = os.path.dirname(os.path.abspath(__file__))
    process_directory(base_dir)
